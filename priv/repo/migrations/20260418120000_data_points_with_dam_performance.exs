defmodule Barragenspt.Repo.Migrations.DataPointsWithDamPerformance do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    execute """
    UPDATE data_points AS dp
    SET basin_id = d.basin_id
    FROM dam AS d
    WHERE d.site_id = dp.site_id
      AND dp.basin_id IS DISTINCT FROM d.basin_id
    """

    execute "DROP VIEW IF EXISTS data_points_with_dam"

    execute """
    CREATE VIEW data_points_with_dam AS
    SELECT
      dp.id,
      dp.site_id,
      dp.basin_id,
      d.name AS dam_name,
      d.basin,
      d.river,
      dp.param_id,
      dp.param_name,
      dp.value,
      dp.colected_at
    FROM dam d
    INNER JOIN data_points dp
      ON d.site_id = dp.site_id
      AND d.basin_id IS NOT DISTINCT FROM dp.basin_id
    """

    execute "DROP INDEX CONCURRENTLY IF EXISTS speed_up_all_the_things"

    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS data_points_basin_colected_id_idx
    ON data_points (basin_id, colected_at DESC, id DESC)
    """

    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS data_points_site_colected_id_idx
    ON data_points (site_id, colected_at DESC, id DESC)
    """

    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS data_points_param_colected_id_idx
    ON data_points (param_id, colected_at DESC, id DESC)
    """

    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS data_points_basin_param_colected_id_idx
    ON data_points (basin_id, param_id, colected_at DESC, id DESC)
    """
  end

  def down do
    execute "DROP INDEX CONCURRENTLY IF EXISTS data_points_basin_param_colected_id_idx"
    execute "DROP INDEX CONCURRENTLY IF EXISTS data_points_param_colected_id_idx"
    execute "DROP INDEX CONCURRENTLY IF EXISTS data_points_site_colected_id_idx"
    execute "DROP INDEX CONCURRENTLY IF EXISTS data_points_basin_colected_id_idx"

    execute """
    CREATE INDEX IF NOT EXISTS speed_up_all_the_things
    ON data_points (param_name, param_id, dam_code, site_id, basin_id, value, colected_at)
    """

    execute "DROP VIEW IF EXISTS data_points_with_dam"

    execute """
    CREATE VIEW data_points_with_dam AS
    SELECT
      dp.id,
      d.site_id,
      d.basin_id,
      d.name AS dam_name,
      d.basin,
      d.river,
      dp.param_id,
      dp.param_name,
      dp.value,
      dp.colected_at
    FROM dam d
    INNER JOIN data_points dp ON d.site_id = dp.site_id
    """
  end
end
