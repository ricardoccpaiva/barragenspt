defmodule Barragenspt.Workers.DataPointsUpdate do
  use Oban.Worker, queue: :data_points_update
  import Ecto.Query
  require Logger
  alias Barragenspt.Models.Hydrometrics.Dam

  @impl Oban.Worker
  def perform(%Oban.Job{attempt: 1, args: %{"jcid" => jcid}}) do
    Barragenspt.Cache.flush()

    # 354895424 - Cota da Albufeira na última hora
    # 1629599726 - Cota da Albufeira
    # 354895398 - Volume armazenado na última hora (dam3)
    # 1629599798 - Volume armazenado
    # 2279 - Caudal afluente médio diário
    # 2284 - Caudal descarregado médio diário
    # 2282 - Caudal turbinado médio diário
    # 212296818 - Caudal efluente médio diário

    data_params = [
      {1_629_599_798, "volume"},
      {354_895_398, "volume_last_hour"},
      {304_545_050, "volume_last_day_month"},
      {1_629_599_726, "elevation"},
      {354_895_424, "elevation_last_hour"},
      {2279, "tributary_daily_flow"},
      {2284, "ouput_flow_rate_daily"},
      {2282, "turbocharged_daily_flow"},
      {212_296_818, "effluent_daily_flow"}
    ]

    current_date = Timex.now()
    {:ok, end_date_str} = Timex.format(current_date, "{D}/{M}/{YYYY}")

    {:ok, start_date_str} =
      current_date |> Timex.shift(months: -1) |> Timex.format("{D}/{M}/{YYYY}")

    # data_params = [{354_895_398, "volume_last_hour"}]
    # data_params = [{1_629_599_798, "volume"}]

    from(d in Dam, where: not is_nil(d.metadata))
    |> Barragenspt.Repo.all()
    |> Enum.map(fn dam ->
      try do
        {max_value, ""} = Integer.parse(dam.metadata["Albufeira"]["Capacidade total (dam3)"])

        Enum.map(data_params, fn {param_id, param_name} ->
          Barragenspt.Workers.FetchDamParameters.new(%{
            "id" => :rand.uniform(999_999_999),
            "parent_jcid" => jcid,
            "dam_code" => dam.code,
            "basin_id" => dam.basin_id,
            "site_id" => dam.site_id,
            "parameter_id" => param_id,
            "parameter_name" => param_name,
            "start_date" => start_date_str,
            "end_date" => end_date_str,
            "max_value" => max_value
          })
        end)
      rescue
        _ -> []
      end
    end)
    |> List.flatten()
    |> tap(&Logger.info("Spawning #{Enum.count(&1)} jobs to update data points"))
    |> Enum.reject(fn row -> row == [] end)
    |> OpentelemetryOban.insert_all()

    Logger.info("Snoozing DataPointsUpdate for the first initial 30s")

    {:snooze, 30}
  end

  def perform(%Oban.Job{attempt: attempt, args: %{"jcid" => jcid}}) when attempt > 1 do
    handle_retry(jcid)
  end

  defp handle_retry(jcid) do
    {:ok,
     %Postgrex.Result{
       columns: ["count"],
       command: :select,
       num_rows: 1,
       rows: [[rows]]
     }} =
      Barragenspt.Repo.query(
        "select count(1) from oban_jobs where args->>'parent_jcid' = '#{jcid}'"
      )

    if rows == 0 do
      Logger.info("DataPointsUpdate coordinator job has finished. parent_jcid = '#{jcid}'")

      :ok
    else
      Logger.info(
        "DataPointsUpdate coordinator job still has child #{rows} jobs running. parent_jcid = '#{jcid}'"
      )

      {:snooze, 30}
    end
  end
end
