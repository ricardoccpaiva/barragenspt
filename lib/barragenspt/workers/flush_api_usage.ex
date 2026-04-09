defmodule Barragenspt.Workers.FlushApiUsage do
  @moduledoc false
  use Oban.Worker, queue: :api_usage, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    case Barragenspt.ApiUsage.drain_closed_buckets() do
      {:ok, 0} ->
        :ok

      {:ok, n} ->
        Logger.info("api usage flush: wrote #{n} bucket row(s)")
        :ok

      {:error, reason} ->
        Logger.error("api usage flush failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
