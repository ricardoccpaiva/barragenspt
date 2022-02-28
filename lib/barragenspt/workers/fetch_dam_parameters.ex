defmodule Barragenspt.Workers.FetchDamParameters do
  use Oban.Worker, queue: :dams_info
  import Ecto.Query
  require Logger
  alias Barragenspt.Hydrometrics.DataPoint

  @timeout 25000

  def spawn_workers do
    # 354895424 - Cota da Albufeira na última hora
    # 1629599726 - Cota da Albufeira
    # 354895398 - Volume armazenado na última hora (dam3)
    # 1629599798 - Volume armazenado
    data_params = [
      {354_895_424, "quota_last_hour"},
      {1_629_599_726, "quota"},
      {1_629_599_798, "volume"},
      {354_895_398, "volume_last_hour"},
      {304_545_050, "volume_last_day_month"}
    ]

    # data_params = [{354_895_398, "volume_last_hour"}]
    # data_params = [{1_629_599_798, "volume"}]

    years = [
      {1990, 2000},
      {2001, 2010},
      {2011, 2022}
    ]

    from(Barragenspt.Hydrometrics.Dam)
    |> Barragenspt.Repo.all()
    |> Enum.map(fn dam ->
      Enum.map(data_params, fn {param_id, param_name} ->
        Enum.map(years, fn {start_year, end_year} ->
          Barragenspt.Workers.FetchDamParameters.new(%{
            "id" => :rand.uniform(999_999_999),
            "dam_code" => dam.code,
            "basin_id" => dam.basin_id,
            "site_id" => dam.site_id,
            "parameter_id" => param_id,
            "parameter_name" => param_name,
            "start_year" => start_year,
            "end_year" => end_year
          })
        end)
      end)
    end)
    |> List.flatten()
    |> Oban.insert_all()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args:
          %{
            "id" => job_id,
            "dam_code" => dam_code,
            "site_id" => site_id,
            "basin_id" => basin_id,
            "parameter_id" => parameter_id,
            "parameter_name" => parameter_name,
            "start_year" => start_year,
            "end_year" => end_year
          } = _args
      }) do
    :timer.sleep(4000)

    site_id
    |> get_raw_csv(parameter_id, start_year, end_year)
    |> write_to_file()
    |> File.stream!()
    |> NimbleCSV.RFC4180.parse_stream()
    |> Stream.drop(4)
    |> Stream.chunk_every(250)
    |> Stream.map(fn row ->
      row
      |> Enum.map(fn row_item ->
        handle_row(
          dam_code,
          site_id,
          basin_id,
          parameter_name,
          parameter_id,
          row_item
        )
      end)
      |> List.flatten()
      |> Enum.reject(fn row -> row == :noop end)
      |> save_rows()
    end)
    |> Stream.run()

    :ok
  end

  defp get_raw_csv(site_id, parameter_id, start_year, end_year) do
    base_url = "https://snirh.apambiente.pt/snirh/_dadosbase/site/paraCSV/dados_csv.php"

    query_params =
      "?sites=#{site_id}&pars=#{parameter_id}&tmin=01/01/#{start_year}&tmax=31/12/#{end_year}&formato=csv"

    options = [recv_timeout: @timeout, timeout: @timeout]
    %HTTPoison.Response{body: body} = HTTPoison.get!(base_url <> query_params, [], options)

    body
  end

  defp write_to_file(body) do
    {:ok, path} = Briefly.create(directory: true)

    file_path = Path.join(path, "#{UUID.uuid4()}.csv")
    :ok = File.write!(file_path, body)

    file_path
  end

  def to_params_string(kv_list) do
    kv_list
    |> Stream.map(fn {k, v} -> {k |> String.downcase() |> String.replace(" ", "_"), v} end)
    |> Stream.map(fn {k, v} -> "#{k}=#{v}" end)
    |> Enum.join(" ")
  end

  defp handle_row(
         dam_code,
         site_id,
         basin_id,
         parameter_name,
         parameter_id,
         [
           date,
           value,
           _measurement_type,
           _nothing
         ]
       ) do
    regex =
      ~r/^(?'day'[0-9]{1,2})\/(?'month'[0-9]{1,2})\/(?'year'[0-9]{4}) (?'hour'[0-9]{2}):(?'minutes'[0-9]{2})$/

    %{
      "day" => day,
      "hour" => hour,
      "minutes" => minutes,
      "month" => month,
      "year" => year
    } = Regex.named_captures(regex, date)

    dt =
      "#{year}-#{month}-#{day}T#{hour}:#{minutes}:00Z"
      |> DateTime.from_iso8601()
      |> then(fn {:ok, dt, 0} -> dt end)

    sanitized_param_name =
      parameter_name
      |> String.downcase()
      |> String.replace(" ", "_")

    date = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    {float_val, _else} = Float.parse(value)

    %{
      param_name: sanitized_param_name,
      param_id: to_string(parameter_id),
      dam_code: dam_code,
      basin_id: to_string(basin_id),
      site_id: site_id,
      value: float_val,
      inserted_at: date,
      updated_at: date,
      colected_at: NaiveDateTime.truncate(dt, :second)
    }
  end

  defp handle_row(_, _, _, _, _, _), do: :noop

  defp save_rows(rows) do
    Barragenspt.Repo.insert_all(DataPoint, rows)
  end
end
