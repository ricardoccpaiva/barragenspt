defmodule Barragenspt.Repo.Migrations.DropBasinStorageView do
  use Ecto.Migration

  def up do
    execute "DROP VIEW IF EXISTS basin_storage;"
  end

  def down do
    execute """
    CREATE VIEW public.basin_storage AS
    SELECT dp.basin_id AS id,
      (SELECT d.basin
         FROM dam d
        WHERE d.basin_id::text = dp.basin_id::text
       LIMIT 1) AS name,
      sum(dp.value) / ((SELECT sum(((d.metadata -> 'Albufeira'::text) ->> 'Capacidade total (dam3)'::text)::numeric) AS sum
         FROM dam d
        WHERE d.basin_id::text = dp.basin_id::text))::numeric * 100::numeric AS current_storage
    FROM (
      SELECT data_points.site_id,
             data_points.basin_id,
             data_points.value,
             row_number() OVER (PARTITION BY data_points.site_id ORDER BY data_points.colected_at DESC) AS rn
      FROM data_points
      WHERE data_points.param_name::text = 'volume_last_day_month'::text
    ) dp
    WHERE dp.rn <= 1
    GROUP BY dp.basin_id;
    """
  end
end
