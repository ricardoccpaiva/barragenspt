defmodule Barragenspt.Repo.Migrations.RecreateBasinStorageView do
  use Ecto.Migration

  def up do
    execute("""
    CREATE VIEW basin_storage AS
      SELECT basin_id as id,
        (select basin from dam d where d.basin_id = dp.basin_id limit 1) as name,
        (SUM(value) / (SELECT sum((metadata  -> 'Albufeira' ->> 'Capacidade total (dam3)')::int) from dam d where basin_id = dp.basin_id)) * 100 as current_storage
      FROM (
        SELECT site_id, basin_id, value, ROW_NUMBER() OVER(PARTITION BY site_id  ORDER BY colected_at  DESC) rn
        FROM data_points
        WHERE param_name = 'volume_last_day_month') dp
      WHERE rn <= 1
      GROUP BY basin_id
    ;
    """)
  end

  def down do
    execute("DROP VIEW basin_storage;")
  end
end
