defmodule Barragenspt.Workers.RealtimeDataPointsUpdate do
  use Oban.Worker, queue: :data_points_update
  import Ecto.Query
  alias Barragenspt.Hydrometrics.Dams
  alias Barragenspt.Models.Hydrometrics.DataPointRealtime
  alias Barragenspt.Repo
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: _args}) do
    Barragenspt.RealtimeDataPointsCache.flush()

    from(DataPointRealtime) |> Repo.delete_all()

    Dams.all()
    |> Enum.map(fn d ->
      Barragenspt.Workers.RealtimeDataExtractor.new(%{"site_id" => d.site_id})
    end)
    |> OpentelemetryOban.insert_all()

    :ok
  end
end
