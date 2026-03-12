defmodule Barragenspt.Repo.Migrations.CreateDataPointsRealtime do
  use Ecto.Migration

  def change do
    create table(:data_points_realtime) do
      add :param_name, :string
      add :param_id, :string
      add :dam_code, :string
      add :site_id, :string
      add :basin_id, :string
      add :value, :decimal
      add :colected_at, :naive_datetime

      timestamps()
    end

    create index(
             :data_points_realtime,
             [:param_name, :param_id, :dam_code, :site_id, :basin_id, :value, :colected_at],
             name: "data_points_realtime_speed_up_all_the_things",
             comment: "Speed up queries on realtime data points"
           )

    create unique_index(:data_points_realtime, [:site_id, :param_id, :colected_at],
             name: "data_points_realtime_site_param_colected_at_index"
           )
  end
end
