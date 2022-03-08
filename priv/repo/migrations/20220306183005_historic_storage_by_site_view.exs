defmodule Barragenspt.Repo.Migrations.HistoricStorageBySiteView do
  use Ecto.Migration

  def up do
    execute("""
      CREATE VIEW site_historic_storage AS
      select month, site_id, avg(average) as value from(
        select cast(extract(month from colected_at) as int) as month, dp.dam_code, dp.site_id, (dp.value / cast(d.metadata  -> 'Albufeira' ->> 'Capacidade total (dam3)' as int))*100 as average
        from data_points dp inner join dam d
        on dp.site_id = d.site_id
        where param_name = 'volume_last_day_month'
        order by colected_at) as details
      group by month, site_id
      order by month, site_id;
    """)
  end

  def down do
    execute("DROP VIEW site_historic_storage;")
  end
end
