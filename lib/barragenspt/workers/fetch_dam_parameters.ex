defmodule Barragenspt.Workers.FetchDamParameters do
  use Oban.Worker, queue: :dams_info
  import Ecto.Query
  require Logger
  alias Barragenspt.Hydrometrics.DataPoint
  alias Barragenspt.Services.Snirh

  def spawn_workers do
    # 354895424 - Cota da Albufeira na última hora
    # 1629599726 - Cota da Albufeira
    # 354895398 - Volume armazenado na última hora (dam3)
    # 1629599798 - Volume armazenado
    data_params = [
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

    from(d in Barragenspt.Hydrometrics.Dam, where: not is_nil(d.metadata))
    |> Barragenspt.Repo.all()
    |> Enum.map(fn dam ->
      try do
        {max_value, ""} = Integer.parse(dam.metadata["Albufeira"]["Capacidade total (dam3)"])

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
              "end_year" => end_year,
              "max_value" => max_value
            })
          end)
        end)
      rescue
        _ -> []
      end
    end)
    |> List.flatten()
    |> Enum.reject(fn row -> row == [] end)
    |> Oban.insert_all()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args:
          %{
            "id" => _job_id,
            "dam_code" => dam_code,
            "site_id" => site_id,
            "basin_id" => basin_id,
            "parameter_id" => parameter_id,
            "parameter_name" => parameter_name,
            "start_year" => start_year,
            "end_year" => end_year,
            "max_value" => max_value
          } = _args
      }) do
    site_id
    |> Snirh.get_raw_csv_data(parameter_id, "01/01/#{start_year}", "31/12/#{end_year}")
    |> NimbleCSV.RFC4180.parse_string()
    |> Stream.drop(4)
    |> Stream.chunk_every(250)
    |> Stream.map(fn row ->
      row
      |> build_rows(dam_code, site_id, basin_id, parameter_name, parameter_id)
      |> List.flatten()
      |> Enum.reject(fn row -> row == :noop end)
      |> Enum.reject(fn %{value: value} -> value > max_value * 1.10 end)
      |> save_rows()
    end)
    |> Stream.run()

    :ok
  end

  defp build_rows(row, dam_code, site_id, basin_id, parameter_name, parameter_id) do
    Enum.map(row, fn row_item ->
      handle_row(
        dam_code,
        site_id,
        basin_id,
        parameter_name,
        parameter_id,
        row_item
      )
    end)
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
    {float_val, _} = Float.parse(value)
    current_date = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    %{
      param_name: sanitize_param_name(parameter_name),
      param_id: to_string(parameter_id),
      dam_code: dam_code,
      basin_id: to_string(basin_id),
      site_id: site_id,
      value: float_val,
      inserted_at: current_date,
      updated_at: current_date,
      colected_at: parse_and_truncate_date(date)
    }
  end

  defp handle_row(_, _, _, _, _, _), do: :noop

  defp save_rows(rows) do
    Barragenspt.Repo.insert_all(DataPoint, rows)
  end

  defp sanitize_param_name(name) do
    name
    |> String.downcase()
    |> String.replace(" ", "_")
  end

  defp parse_and_truncate_date(date) do
    Timex.parse(date, "{0D}/{0M}/{YYYY} {h24}:{m}")
    |> then(fn {:ok, date} -> date end)
    |> NaiveDateTime.truncate(:second)
  end
end
