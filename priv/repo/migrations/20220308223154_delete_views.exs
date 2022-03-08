defmodule Barragenspt.Repo.Migrations.DeleteViews do
  use Ecto.Migration

  def up do
    execute("DROP VIEW basin_historic_storage;")
    execute("DROP VIEW site_historic_storage;")
  end
end
