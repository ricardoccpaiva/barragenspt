defmodule Barragenspt.Repo.Migrations.DropBasinHistoricStorageView do
  use Ecto.Migration

  def up do
    execute "DROP VIEW IF EXISTS basin_historic_storage;"
  end

  def down do
    execute """
    CREATE VIEW basin_historic_storage AS
    SELECT month, basin_id, avg(average) AS value
    FROM (
      SELECT
        cast(extract(month FROM colected_at) AS int) AS month,
        dp.dam_code,
        dp.basin_id,
        dp.site_id,
        (dp.value / cast(d.metadata -> 'Albufeira' ->> 'Capacidade total (dam3)' AS numeric)) * 100 AS average
      FROM data_points dp
      INNER JOIN dam d ON dp.site_id = d.site_id
      WHERE param_name = 'volume_last_day_month'
      ORDER BY colected_at
    ) AS details
    GROUP BY month, basin_id
    ORDER BY month, basin_id;
    """
  end
end
