defmodule Barragenspt.Repo.Migrations.CreateMonthlyAverageStorageBySiteMaterialized do
  use Ecto.Migration

  def up do
    execute """
    CREATE MATERIALIZED VIEW monthly_average_storage_by_site AS
    SELECT period, site_id, avg(average) AS value
    FROM (
      SELECT
        cast(extract(month FROM colected_at) AS int) AS period,
        dp.dam_code,
        dp.site_id,
        (dp.value / d.total_capacity) * 100 AS average
      FROM data_points dp
      INNER JOIN dam d ON dp.site_id = d.site_id
      WHERE param_name = 'volume_last_day_month'
      ORDER BY colected_at
    ) AS details
    GROUP BY period, site_id
    ORDER BY period, site_id;
    """

    create unique_index(:monthly_average_storage_by_site, [:period, :site_id])
  end

  def down do
    drop index(:monthly_average_storage_by_site, [:period, :site_id])
    execute "DROP MATERIALIZED VIEW IF EXISTS monthly_average_storage_by_site;"
  end
end
