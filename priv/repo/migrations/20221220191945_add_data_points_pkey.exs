defmodule Barragenspt.Repo.Migrations.AddDataPointsPkey do
  use Ecto.Migration

  def up do
    create unique_index(:data_points, [:site_id, :param_id, :colected_at])
  end

  def down do
    drop unique_index(:data_points, [:site_id, :param_id, :colected_at])
  end
end
