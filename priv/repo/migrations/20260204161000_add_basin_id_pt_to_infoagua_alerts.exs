defmodule Barragenspt.Repo.Migrations.AddBasinIdPtToInfoaguaAlerts do
  use Ecto.Migration

  def change do
    alter table(:infoagua_alerts) do
      add :basin_id_pt, :string
    end

    create index(:infoagua_alerts, [:basin_id_pt])
  end
end
