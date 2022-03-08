defmodule Barragenspt.Repo.Migrations.HistoricStorageByBasinView do
  use Ecto.Migration

  def up do
    execute("""
      CREATE VIEW basin_historic_storage AS
      select month, basin_id, avg(average) as value from(
        select cast(extract(month from colected_at) as int) as month, dp.dam_code, dp.basin_id, dp.site_id, (dp.value / cast(d.metadata  -> 'Albufeira' ->> 'Capacidade total (dam3)' as int))*100 as average
        from data_points dp inner join dam d
        on dp.site_id = d.site_id
        where param_name = 'volume_last_day_month'
        order by colected_at) as details
      group by month, basin_id
      order by month, basin_id;
    """)
  end

  def down do
    execute("DROP VIEW basin_historic_storage;")
  end
end
