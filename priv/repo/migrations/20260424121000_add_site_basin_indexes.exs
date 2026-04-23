defmodule Barragenspt.Repo.Migrations.AddSiteBasinIndexes do
  use Ecto.Migration

  def change do
    create index(:data_points, [:site_id, :basin_id], name: :data_points_site_basin_idx)
    create index(:dam, [:site_id, :basin_id], name: :dam_site_basin_idx)
  end
end
