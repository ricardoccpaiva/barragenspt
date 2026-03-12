defmodule Barragenspt.Repo.Migrations.UpdateSiteCurrentStorageViewAddColectedAt do
  use Ecto.Migration

  def up do
    execute("""
    DO $$ BEGIN
      IF EXISTS (SELECT 1 FROM pg_matviews WHERE schemaname = 'public' AND matviewname = 'site_current_storage') THEN
        DROP MATERIALIZED VIEW site_current_storage;
      ELSIF EXISTS (SELECT 1 FROM pg_views WHERE schemaname = 'public' AND viewname = 'site_current_storage') THEN
        DROP VIEW site_current_storage;
      END IF;
    END $$;
    """)

    execute("""
    CREATE VIEW site_current_storage AS
      SELECT basin_id, site_id,
        (select name from dam d where d.site_id = dp.site_id limit 1) as site_name,
        (select basin from dam d where d.site_id = dp.site_id limit 1) as basin_name,
        (SUM(value) / (SELECT sum((metadata  -> 'Albufeira' ->> 'Capacidade total (dam3)')::int) from dam d where site_id  = dp.site_id)) * 100 as current_storage,
        MAX(colected_at) as colected_at
      FROM (
        SELECT site_id, basin_id, value, colected_at, ROW_NUMBER() OVER(PARTITION BY site_id  ORDER BY colected_at  DESC) rn
        FROM data_points
        WHERE param_name = 'volume_last_hour') dp
      WHERE rn <= 1
      GROUP BY site_id, basin_id
    ;
    """)
  end

  def down do
    execute("""
    DO $$ BEGIN
      IF EXISTS (SELECT 1 FROM pg_matviews WHERE schemaname = 'public' AND matviewname = 'site_current_storage') THEN
        DROP MATERIALIZED VIEW site_current_storage;
      ELSIF EXISTS (SELECT 1 FROM pg_views WHERE schemaname = 'public' AND viewname = 'site_current_storage') THEN
        DROP VIEW site_current_storage;
      END IF;
    END $$;
    """)

    execute("""
    CREATE VIEW site_current_storage AS
      SELECT basin_id, site_id,
        (select name from dam d where d.site_id = dp.site_id limit 1) as site_name,
        (select basin from dam d where d.site_id = dp.site_id limit 1) as basin_name,
        (SUM(value) / (SELECT sum((metadata  -> 'Albufeira' ->> 'Capacidade total (dam3)')::int) from dam d where site_id  = dp.site_id)) * 100 as current_storage
      FROM (
        SELECT site_id, basin_id, value, ROW_NUMBER() OVER(PARTITION BY site_id  ORDER BY colected_at  DESC) rn
        FROM data_points
        WHERE param_name = 'volume_last_hour') dp
      WHERE rn <= 1
      GROUP BY site_id, basin_id
    ;
    """)
  end
end
