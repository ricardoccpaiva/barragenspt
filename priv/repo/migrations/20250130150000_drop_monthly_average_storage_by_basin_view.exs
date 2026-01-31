defmodule Barragenspt.Repo.Migrations.DropMonthlyAverageStorageByBasinView do
  use Ecto.Migration

  def up do
    execute "DROP VIEW IF EXISTS monthly_average_storage_by_basin;"
  end

  def down do
    # Recreate the view that selects from the materialized view (if MV exists)
    execute """
    CREATE VIEW monthly_average_storage_by_basin AS
    SELECT period, basin_id, value FROM monthly_average_storage_by_basin_mv;
    """
  end
end
