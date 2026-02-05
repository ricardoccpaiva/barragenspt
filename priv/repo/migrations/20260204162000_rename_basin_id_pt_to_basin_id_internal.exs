defmodule Barragenspt.Repo.Migrations.RenameBasinIdPtToBasinIdInternal do
  use Ecto.Migration

  def change do
    rename table(:infoagua_alerts), :basin_id_pt, to: :basin_id_internal
  end
end
