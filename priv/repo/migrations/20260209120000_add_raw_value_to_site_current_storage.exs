defmodule Barragenspt.Repo.Migrations.AddRawValueToSiteCurrentStorage do
  use Ecto.Migration

  def up do
    execute("""
    DO $$ BEGIN
      IF EXISTS (SELECT 1 FROM pg_matviews WHERE schemaname = 'public' AND matviewname = 'site_current_storage') THEN
        DROP INDEX IF EXISTS site_current_storage_site_id_index;
        DROP MATERIALIZED VIEW site_current_storage;
      ELSIF EXISTS (SELECT 1 FROM pg_views WHERE schemaname = 'public' AND viewname = 'site_current_storage') THEN
        DROP VIEW site_current_storage;
      END IF;
    END $$;
    """)

    execute """
    CREATE MATERIALIZED VIEW site_current_storage AS
    SELECT
      dp.site_id,
      dp.value AS current_storage_value,
      dp.value / (SELECT sum(total_capacity) FROM dam d WHERE d.site_id = dp.site_id) * 100 AS current_storage_pct,
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
    execute("""
    DO $$ BEGIN
      IF EXISTS (SELECT 1 FROM pg_matviews WHERE schemaname = 'public' AND matviewname = 'site_current_storage') THEN
        DROP INDEX IF EXISTS site_current_storage_site_id_index;
        DROP MATERIALIZED VIEW site_current_storage;
      ELSIF EXISTS (SELECT 1 FROM pg_views WHERE schemaname = 'public' AND viewname = 'site_current_storage') THEN
        DROP VIEW site_current_storage;
      END IF;
    END $$;
    """)

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
end

