defmodule Barragenspt.Workers.RealtimeDataPointsUpdate do
  use Oban.Worker, queue: :data_points_update
  alias Barragenspt.Hydrometrics.Dams
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: _args}) do
    Barragenspt.RealtimeDataPointsCache.flush()

    Dams.all()
    |> Enum.map(fn d ->
      Barragenspt.Workers.RealtimeDataExtractor.new(%{"site_id" => d.site_id})
    end)
    |> OpentelemetryOban.insert_all()

    :ok
  end
end
