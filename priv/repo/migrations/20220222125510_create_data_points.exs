defmodule Barragenspt.Repo.Migrations.CreateDataPoints do
  use Ecto.Migration

  def change do
    create table(:data_points) do
      add :param_name, :string
      add :param_id, :string
      add :dam_code, :string
      add :site_id, :string
      add :basin_id, :string
      add :value, :decimal
      add :colected_at, :naive_datetime

      timestamps()
    end
  end
end
