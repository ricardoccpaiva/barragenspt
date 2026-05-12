defmodule Barragenspt.Repo.Migrations.AddDataPointsSiteParamCollectedIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS data_points_site_param_collected_idx
    ON data_points (site_id, param_name, colected_at)
    """
  end

  def down do
    execute "DROP INDEX CONCURRENTLY IF EXISTS data_points_site_param_collected_idx"
  end
end
