defmodule Barragenspt.Repo.Migrations.AddDataPointsFilterIndexes do
  use Ecto.Migration

  def change do
    create index(:data_points, [:param_name], name: :data_points_param_name_idx)
    create index(:data_points, [:basin_id], name: :data_points_basin_id_idx)
    create index(:data_points, [:site_id], name: :data_points_site_id_idx)
  end
end
