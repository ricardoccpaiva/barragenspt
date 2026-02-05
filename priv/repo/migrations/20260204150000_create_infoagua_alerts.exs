defmodule Barragenspt.Repo.Migrations.CreateInfoaguaAlerts do
  use Ecto.Migration

  def change do
    create table(:infoagua_alerts) do
      add :basin_id, :integer, null: false
      add :color, :string, null: false
      add :last_update, :naive_datetime, null: false
      add :name, :string, null: false
      add :snirh_source_id, :bigint, null: false
      add :station_id, :integer, null: false
      add :value, :string, null: false

      timestamps()
    end

    create index(:infoagua_alerts, [:basin_id])
    create index(:infoagua_alerts, [:snirh_source_id])
  end
end
