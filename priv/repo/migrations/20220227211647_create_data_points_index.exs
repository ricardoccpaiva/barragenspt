defmodule Barragenspt.Repo.Migrations.CreateDataPointsIndex do
  use Ecto.Migration

  def up do
    create index()
  end

  def down do
    drop index()
  end

  defp index do
    index(
      :data_points,
      [:param_name, :param_id, :dam_code, :site_id, :basin_id, :value, :colected_at],
      comment: "Speed up all the things",
      name: "speed_up_all_the_things"
    )
  end
end
