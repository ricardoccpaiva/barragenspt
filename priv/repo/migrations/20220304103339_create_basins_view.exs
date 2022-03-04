defmodule Barragenspt.Repo.Migrations.CreateBasinsView do
  use Ecto.Migration

  def up do
    execute """
    CREATE VIEW basins AS
      SELECT basin_id as id, basin as name
      from dam
      group by basin_id, basin
    ;
    """
  end

  def down do
    execute "DROP VIEW basins;"
  end
end
