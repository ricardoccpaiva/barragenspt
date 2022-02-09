defmodule Barragenspt.Workers.FetchDamParameters do
  use Oban.Worker, queue: :dams_info
  import Ecto.Query
  require Logger

  @timeout 25000

  def stuff do
    from(Barragenspt.Hydrometrics.Dam)
    |> Barragenspt.Repo.all()
    |> Enum.each(fn dam ->
      total_volume = dam.metadata["Albufeira"]["Capacidade total (dam3)"]
      max_quota = dam.metadata["Albufeira"]["Cota do nível de pleno armazenamento - NPA (m)"]
      IO.puts(~s(total_volume ----> #{total_volume}))
      IO.puts(~s(max_quota ----> #{max_quota}))
    end)
  end

  def spawn_workers do
    # 354895424 - Cota da Albufeira na última hora
    # 1629599726 - Cota da Albufeira
    # 354895398 - Volume armazenado na última hora (dam3)
    # 1629599798 - Volume armazenado
    data_params = [
      {354_895_424, "quota_last_hour"},
      {1_629_599_726, "quota"},
      {1_629_599_798, "volume"},
      {354_895_398, "volume_last_hour"}
    ]

    # data_params = [{354_895_398, "volume_last_hour"}]
    # data_params = [{1_629_599_798, "volume"}]

    from(Barragenspt.Hydrometrics.Dam)
    |> Barragenspt.Repo.all()
    |> Enum.map(fn dam ->
      Enum.map(data_params, fn {param_id, param_name} ->
        Barragenspt.Workers.FetchDamParameters.new(%{
          "id" => :rand.uniform(999_999_999),
          "dam_code" => dam.code,
          "basin_id" => dam.basin_id,
          "site_id" => dam.site_id,
          "parameter_id" => param_id,
          "parameter_name" => param_name,
          "total_volume" => dam.metadata["Albufeira"]["Capacidade total (dam3)"],
          "max_quota" =>
            dam.metadata["Albufeira"]["Cota do nível de pleno armazenamento - NPA (m)"]
        })
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
            "total_volume" => total_volume,
            "max_quota" => max_quota
          } = _args
      }) do
    :timer.sleep(4000)
    File.rm_rf("resources/tmp/job_#{job_id}")
    File.mkdir("resources/tmp")
    File.mkdir("resources/tmp/job_#{job_id}")

    site_id
    |> get_raw_csv(parameter_id)
    |> write_to_file(site_id, job_id)
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
          total_volume,
          max_quota,
          row_item
        )
      end)
      |> Enum.reject(fn row -> row == :noop end)
      |> Enum.join("\n")
      |> save_to_influx_cloud()
    end)
    |> Stream.run()

    File.rm_rf!("resources/tmp/job_#{job_id}")

    :ok
  end

  defp get_raw_csv(site_id, parameter_id) do
    base_url = "https://snirh.apambiente.pt/snirh/_dadosbase/site/paraCSV/dados_csv.php"

    query_params =
      "?sites=#{site_id}&pars=#{parameter_id}&tmin=01/08/2010&tmax=31/01/2022&formato=csv"

    options = [recv_timeout: @timeout, timeout: @timeout]
    %HTTPoison.Response{body: body} = HTTPoison.get!(base_url <> query_params, [], options)

    body
  end

  defp write_to_file(body, site_id, job_id) do
    filename = "resources/tmp/job_#{job_id}/#{site_id}.csv"

    :ok = File.write!(filename, body)

    filename
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
         total_volume,
         max_quota,
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

    ts =
      "#{year}-#{month}-#{day}T#{hour}:#{minutes}:00Z"
      |> DateTime.from_iso8601()
      |> then(fn {:ok, dt, 0} -> dt end)
      |> DateTime.to_unix()

    sanitized_param_name =
      parameter_name
      |> String.downcase()
      |> String.replace(" ", "_")

    value_pct =
      case parameter_name do
        "volume" -> calculate_pct(value, total_volume)
        "volume_last_hour" -> calculate_pct(value, total_volume)
        "quota" -> calculate_pct(value, max_quota)
        "quota_last_hour" -> calculate_pct(value, max_quota)
      end

    "#{sanitized_param_name}_pct,dam_code=#{dam_code},basin_id=#{basin_id},site_id=#{site_id} value=#{value_pct} #{ts}\n" <>
      "#{sanitized_param_name},dam_code=#{dam_code},basin_id=#{basin_id},site_id=#{site_id},parameter_id=#{parameter_id} value=#{value} #{ts}"
  end

  defp handle_row(_, _, _, _, _, _, _, _), do: :noop

  defp calculate_pct(value, total_value) do
    {float_val, _else} = Float.parse(value)
    {float_total_val, _else} = Float.parse(total_value)
    Float.ceil(float_val / float_total_val * 100, 2)
  end

  defp save_to_influx(payload) do
    headers = [{"Content-Type", "text/plain; charset=utf-8"}]

    %HTTPoison.Response{status_code: 204} =
      HTTPoison.post!(
        "http://pi4:8086/api/v2/write?bucket=barragenspt&precision=s",
        payload,
        headers
      )

    # :timer.sleep(50)

    :ok
  end

  defp save_to_influx_cloud(payload) do
    token = System.get_env("INFLUX_CLOUD_API_TOKEN")

    headers = [
      {"Content-Type", "text/plain; charset=utf-8"},
      {"Authorization", "Token #{token}"}
    ]

    %HTTPoison.Response{status_code: 204} =
      HTTPoison.post!(
        "https://europe-west1-1.gcp.cloud2.influxdata.com/api/v2/write?bucket=barragenspt&precision=s",
        payload,
        headers
      )

    # :timer.sleep(50)

    :ok
  end
end
