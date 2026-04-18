defmodule Barragenspt.Repo.Migrations.AddSiteBasinIdsToDataPointsWithDamView do
  use Ecto.Migration

  def up do
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

  def down do
    execute "DROP VIEW IF EXISTS data_points_with_dam"

    execute """
    CREATE VIEW data_points_with_dam AS
    SELECT
      dp.id,
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
