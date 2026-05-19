defmodule Barragenspt.Repo.Migrations.ReplaceDataPointsWithDamView do
  use Ecto.Migration

  def up do
    execute """
    CREATE OR REPLACE VIEW public.data_points_with_dam AS
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
    FROM data_points dp
    JOIN dam d
      ON d.site_id = dp.site_id
     AND d.basin_id IS NOT DISTINCT FROM dp.basin_id
    """
  end

  def down do
    execute """
    CREATE OR REPLACE VIEW public.data_points_with_dam AS
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
  end
end
