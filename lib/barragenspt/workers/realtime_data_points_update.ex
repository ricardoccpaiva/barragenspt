defmodule Barragenspt.Workers.RealtimeDataPointsUpdate do
  use Oban.Worker, queue: :data_points_update
  alias Barragenspt.Hydrometrics.Dams
  require Logger
  alias Barragenspt.WorkerStatus

  @impl Oban.Worker
  def perform(%Oban.Job{id: job_id, attempt: 1}) do
    run_key = "realtime-data-points-update:#{job_id}"
    Barragenspt.RealtimeDataPointsCache.flush()
    _ = WorkerStatus.start_run(__MODULE__, run_key, job_id)

    Dams.all()
    |> Enum.map(fn d ->
      Barragenspt.Workers.RealtimeDataExtractor.new(%{
        "site_id" => d.site_id,
        "run_key" => run_key
      })
    end)
    |> OpentelemetryOban.insert_all()

    {:snooze, 30}
  end

  def perform(%Oban.Job{id: job_id, attempt: attempt}) when attempt > 1 do
    run_key = "realtime-data-points-update:#{job_id}"

    remaining =
      WorkerStatus.remaining_child_jobs(run_key, Barragenspt.Workers.RealtimeDataExtractor)

    if remaining == 0 do
      status =
        if WorkerStatus.child_jobs_have_errors?(
             run_key,
             Barragenspt.Workers.RealtimeDataExtractor
           ),
           do: "error",
           else: "ok"

      _ = WorkerStatus.finish_run(run_key, status)
      :ok
    else
      Logger.info("RealtimeDataPointsUpdate waiting for #{remaining} child jobs")
      {:snooze, 30}
    end
  end
end
