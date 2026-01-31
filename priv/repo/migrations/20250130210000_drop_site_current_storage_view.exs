defmodule Barragenspt.Repo.Migrations.DropSiteCurrentStorageView do
  use Ecto.Migration

  def up do
    execute "DROP VIEW IF EXISTS site_current_storage;"
  end

  def down do
    execute """
    CREATE VIEW site_current_storage AS
    SELECT site_id,
      (SUM(value) / (SELECT sum((metadata -> 'Albufeira' ->> 'Capacidade total (dam3)')::int) FROM dam d WHERE site_id = dp.site_id)) * 100 AS current_storage,
      MAX(colected_at) AS colected_at
    FROM (
      SELECT site_id, value, colected_at, ROW_NUMBER() OVER (PARTITION BY site_id ORDER BY colected_at DESC) rn
      FROM data_points
      WHERE param_name = 'volume_last_hour'
    ) dp
    WHERE rn <= 1
    GROUP BY site_id;
    """
  end
end
