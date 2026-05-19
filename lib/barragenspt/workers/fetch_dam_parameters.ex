defmodule Barragenspt.Workers.FetchDamParameters do
  use Oban.Worker, queue: :dams_info
  import Ecto.Query
  require Logger
  alias Barragenspt.Models.Hydrometrics.{DataPoint, Dam}
  alias Barragenspt.Services.Snirh
  alias Barragenspt.WorkerStatus

  def spawn_workers do
    # 354895424 - Cota da Albufeira na última hora
    # 1629599726 - Cota da Albufeira
    # 354895398 - Volume armazenado na última hora (dam3)
    # 1629599798 - Volume armazenado
    data_params = [
      {1_629_599_798, "volume"},
      {354_895_398, "volume_last_hour"},
      {304_545_050, "volume_last_day_month"},
      {2284, "ouput_flow_rate_daily"},
      {2279, "tributary_daily_flow"},
      {212_296_818, "effluent_daily_flow"},
      {2282, "turbocharged_daily_flow"},
      {1866, "volume_conventional"}
    ]

    # data_params = [{354_895_398, "volume_last_hour"}]
    # data_params = [{1_629_599_798, "volume"}]

    years = [
      {1990, 2000},
      {2001, 2010},
      {2011, 2026}
    ]

    from(d in Dam, where: not is_nil(d.metadata))
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
              "start_date" => "01/01/#{start_year}",
              "end_date" => "31/12/#{end_year}",
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
    |> OpentelemetryOban.insert_all()
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
            "start_date" => start_date,
            "end_date" => end_date,
            "max_value" => max_value
          } = args
      }) do
    run_key = Map.get(args, "run_key")

    site_id
    |> Snirh.get_raw_csv_data(parameter_id, start_date, end_date)
    |> NimbleCSV.RFC4180.parse_string()
    |> Stream.drop(4)
    |> Stream.chunk_every(250)
    |> Stream.map(fn row ->
      row
      |> build_rows(dam_code, site_id, basin_id, parameter_name, parameter_id)
      |> List.flatten()
      |> Enum.reject(fn row -> row == :noop end)
      |> Enum.reject(fn %{value: value} -> value > max_value * 1.10 end)
      |> save_rows(run_key)
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

  defp save_rows([], _run_key), do: {0, 0}

  defp save_rows(rows, run_key) do
    keys = Enum.map(rows, &{&1.site_id, &1.param_id, &1.colected_at}) |> Enum.uniq()

    existing_keys_filter =
      Enum.reduce(keys, dynamic(false), fn {site_id, param_id, colected_at}, dyn ->
        dynamic(
          [d],
          ^dyn or
            (d.site_id == ^site_id and d.param_id == ^param_id and d.colected_at == ^colected_at)
        )
      end)

    existing_count =
      from(d in DataPoint,
        where: ^existing_keys_filter,
        select: count(d.site_id)
      )
      |> Barragenspt.Repo.one()

    {affected_rows, _} =
      Barragenspt.Repo.insert_all(DataPoint, rows,
        on_conflict: :replace_all,
        conflict_target: [:site_id, :param_id, :colected_at]
      )

    updated_rows = min(existing_count, affected_rows)
    created_rows = max(affected_rows - updated_rows, 0)

    if is_binary(run_key) and run_key != "" do
      _ = WorkerStatus.add_rows(run_key, created_rows, updated_rows)
    end

    {created_rows, updated_rows}
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
