defmodule Barragenspt.Repo.Migrations.DropDailyAverageStorageByBasinView do
  use Ecto.Migration

  def up do
    execute "DROP VIEW IF EXISTS daily_average_storage_by_basin;"
  end

  def down do
    execute """
    CREATE VIEW daily_average_storage_by_basin AS
    SELECT period, basin_id, avg(average) AS value
    FROM (
      SELECT
        cast(extract(day FROM colected_at) AS int) || '-' || cast(extract(month FROM colected_at) AS int) AS period,
        dp.dam_code,
        dp.basin_id,
        dp.site_id,
        (dp.value / cast(d.metadata -> 'Albufeira' ->> 'Capacidade total (dam3)' AS numeric)) * 100 AS average
      FROM data_points dp
      INNER JOIN dam d ON dp.site_id = d.site_id
      WHERE param_name = 'volume_last_hour'
      ORDER BY colected_at
    ) AS details
    GROUP BY period, basin_id
    ORDER BY period, basin_id;
    """
  end
end
