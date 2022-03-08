defmodule Barragenspt.Repo.Migrations.DailyAverageStorageByBasinView do
  use Ecto.Migration

  def up do
    execute("""
      CREATE VIEW daily_average_storage_by_basin AS
      select period, basin_id, avg(average) as value from(
        select cast(extract(day from colected_at) as int) || '-' || cast(extract(month from colected_at) as int) as period, dp.dam_code, dp.basin_id, dp.site_id, (dp.value / cast(d.metadata  -> 'Albufeira' ->> 'Capacidade total (dam3)' as int))*100 as average
        from data_points dp inner join dam d
        on dp.site_id = d.site_id
        where param_name = 'volume_last_hour'
        order by colected_at) as details
      group by period, basin_id
      order by period, basin_id;
    """)
  end

  def down do
    execute("DROP VIEW daily_average_storage_by_basin;")
  end
end
