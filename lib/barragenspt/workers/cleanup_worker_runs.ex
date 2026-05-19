defmodule Barragenspt.Workers.CleanupWorkerRuns do
  @moduledoc false
  use Oban.Worker, queue: :maintenance, max_attempts: 3

  require Logger

  alias Barragenspt.WorkerStatus

  @retention_days 30

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    case WorkerStatus.cleanup_runs_older_than_days(@retention_days) do
      {:ok, count} ->
        Logger.info("worker runs cleanup: removed #{count} row(s) older than #{@retention_days} days")
        :ok

      {:error, reason} ->
        Logger.error("worker runs cleanup failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
