defmodule Barragenspt.Workers.RefreshMaterializedViews do
  use Oban.Worker, queue: :data_points_update
  require Logger

  @impl Oban.Worker
  def perform(_args) do
    Barragenspt.Repo.query!("REFRESH MATERIALIZED VIEW CONCURRENTLY site_current_storage")

    Barragenspt.Repo.query!(
      "REFRESH MATERIALIZED VIEW CONCURRENTLY daily_average_storage_by_site"
    )

    Barragenspt.Repo.query!(
      "REFRESH MATERIALIZED VIEW CONCURRENTLY monthly_average_storage_by_site"
    )

    :ok
  end
end
