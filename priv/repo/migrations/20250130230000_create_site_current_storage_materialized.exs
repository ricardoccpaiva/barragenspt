defmodule Barragenspt.Repo.Migrations.CreateSiteCurrentStorageMaterialized do
  use Ecto.Migration

  def up do
    execute """
    CREATE MATERIALIZED VIEW site_current_storage AS
    SELECT
      dp.site_id,
      dp.value / (SELECT sum(total_capacity) FROM dam d WHERE d.site_id = dp.site_id) * 100 AS current_storage,
      dp.colected_at
    FROM (
      SELECT DISTINCT ON (site_id)
        site_id,
        value,
        colected_at
      FROM data_points
      WHERE param_name = 'volume_last_hour'
      ORDER BY site_id, colected_at DESC
    ) dp;
    """

    create unique_index(:site_current_storage, [:site_id])
  end

  def down do
    drop index(:site_current_storage, [:site_id])
    execute "DROP MATERIALIZED VIEW IF EXISTS site_current_storage;"
  end
end
