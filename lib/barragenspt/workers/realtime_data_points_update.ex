defmodule Barragenspt.Workers.RealtimeDataPointsUpdate do
  use Oban.Worker, queue: :data_points_update
  import Ecto.Query
  alias Barragenspt.Hydrometrics.Dams
  alias Barragenspt.Models.Hydrometrics.DataPointRealtime
  alias Barragenspt.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: _args}) do
    from(DataPointRealtime) |> Repo.delete_all()
    site_ids = Enum.map(Dams.all(), & &1.site_id)

    Enum.each(site_ids, &Barragenspt.Services.RealtimeDataExtractor.fetch/1)
    :ok
  end
end
