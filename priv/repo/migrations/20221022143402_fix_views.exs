defmodule Barragenspt.Repo.Migrations.FixViews do
  use Ecto.Migration

  def up do
    execute("""
    CREATE OR REPLACE VIEW public.basin_storage
    AS SELECT dp.basin_id AS id,
    ( SELECT d.basin
           FROM dam d
          WHERE d.basin_id::text = dp.basin_id::text
         LIMIT 1) AS name,
    sum(dp.value) / (( SELECT sum(((d.metadata -> 'Albufeira'::text) ->> 'Capacidade total (dam3)'::text)::numeric) AS sum
           FROM dam d
          WHERE d.basin_id::text = dp.basin_id::text))::numeric * 100::numeric AS current_storage
    FROM ( SELECT data_points.site_id,
            data_points.basin_id,
            data_points.value,
            row_number() OVER (PARTITION BY data_points.site_id ORDER BY data_points.colected_at DESC) AS rn
           FROM data_points
          WHERE data_points.param_name::text = 'volume_last_day_month'::text) dp
    WHERE dp.rn <= 1
    GROUP BY dp.basin_id;
    """)

    execute("""
    CREATE OR REPLACE VIEW basin_historic_storage AS
      select month, basin_id, avg(average) as value from(
        select cast(extract(month from colected_at) as int) as month, dp.dam_code, dp.basin_id, dp.site_id, (dp.value / cast(d.metadata  -> 'Albufeira' ->> 'Capacidade total (dam3)' as numeric))*100 as average
        from data_points dp inner join dam d
        on dp.site_id = d.site_id
        where param_name = 'volume_last_day_month'
        order by colected_at) as details
      group by month, basin_id
      order by month, basin_id;
    """)

    execute("""
      CREATE OR REPLACE VIEW site_historic_storage AS
      select month, site_id, avg(average) as value from(
        select cast(extract(month from colected_at) as int) as month, dp.dam_code, dp.site_id, (dp.value / cast(d.metadata  -> 'Albufeira' ->> 'Capacidade total (dam3)' as numeric))*100 as average
        from data_points dp inner join dam d
        on dp.site_id = d.site_id
        where param_name = 'volume_last_day_month'
        order by colected_at) as details
      group by month, site_id
      order by month, site_id;
    """)

    execute("""
    CREATE OR REPLACE VIEW monthly_average_storage_by_site AS
      select period, site_id, avg(average) as value from(
        select cast(extract(month from colected_at) as int) as period, dp.dam_code, dp.site_id, (dp.value / cast(d.metadata  -> 'Albufeira' ->> 'Capacidade total (dam3)' as numeric))*100 as average
        from data_points dp inner join dam d
        on dp.site_id = d.site_id
        where param_name = 'volume_last_day_month'
        order by colected_at) as details
      group by period, site_id
      order by period, site_id;
    """)

    execute("""
      CREATE OR REPLACE VIEW monthly_average_storage_by_basin AS
      select period, basin_id, avg(average) as value from(
        select cast(extract(month from colected_at) as int) as period, dp.dam_code, dp.basin_id, dp.site_id, (dp.value / cast(d.metadata  -> 'Albufeira' ->> 'Capacidade total (dam3)' as numeric))*100 as average
        from data_points dp inner join dam d
        on dp.site_id = d.site_id
        where param_name = 'volume_last_day_month'
        order by colected_at) as details
      group by period, basin_id
      order by period, basin_id;
    """)

    execute("""
      CREATE OR REPLACE VIEW daily_average_storage_by_site AS
      select period, site_id, avg(average) as value from(
        select cast(extract(day from colected_at) as int) || '-' || cast(extract(month from colected_at) as int) as period, dp.dam_code, dp.site_id, (dp.value / cast(d.metadata  -> 'Albufeira' ->> 'Capacidade total (dam3)' as numeric))*100 as average
        from data_points dp inner join dam d
        on dp.site_id = d.site_id
        where param_name = 'volume_last_hour'
        order by colected_at) as details
      group by period, site_id
      order by period, site_id;
    """)

    execute("""
      CREATE OR REPLACE VIEW daily_average_storage_by_basin AS
      select period, basin_id, avg(average) as value from(
        select cast(extract(day from colected_at) as int) || '-' || cast(extract(month from colected_at) as int) as period, dp.dam_code, dp.basin_id, dp.site_id, (dp.value / cast(d.metadata  -> 'Albufeira' ->> 'Capacidade total (dam3)' as numeric))*100 as average
        from data_points dp inner join dam d
        on dp.site_id = d.site_id
        where param_name = 'volume_last_hour'
        order by colected_at) as details
      group by period, basin_id
      order by period, basin_id;
    """)
  end
end
