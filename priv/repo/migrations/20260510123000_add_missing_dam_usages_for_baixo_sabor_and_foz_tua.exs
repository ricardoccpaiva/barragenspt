defmodule Barragenspt.Repo.Migrations.AddMissingDamUsagesForBaixoSaborAndFozTua do
  use Ecto.Migration

  def up do
    execute("""
    WITH vals(site_id, usage_name) AS (
      VALUES
        ('7554777518', 'Energia'),
        ('9321904688', 'Energia')
    ),
    missing AS (
      SELECT vals.site_id, vals.usage_name
      FROM vals
      WHERE NOT EXISTS (
        SELECT 1
        FROM dam_usage du
        WHERE du.site_id = vals.site_id
          AND du.usage_name = vals.usage_name
      )
    ),
    numbered AS (
      SELECT
        site_id,
        usage_name,
        row_number() OVER (ORDER BY site_id, usage_name) AS row_num
      FROM missing
    ),
    max_id AS (
      SELECT COALESCE(MAX(id), 0) AS base_id
      FROM dam_usage
    )
    INSERT INTO dam_usage (id, site_id, usage_name, inserted_at, updated_at)
    SELECT
      max_id.base_id + numbered.row_num,
      numbered.site_id,
      numbered.usage_name,
      timezone('utc', now()),
      timezone('utc', now())
    FROM numbered
    CROSS JOIN max_id;
    """)

    execute("""
    SELECT setval(
      pg_get_serial_sequence('dam_usage', 'id'),
      COALESCE((SELECT MAX(id) FROM dam_usage), 1),
      true
    );
    """)
  end

  def down do
    execute("""
    DELETE FROM dam_usage
    WHERE usage_name = 'Energia'
      AND site_id IN ('7554777518', '9321904688');
    """)
  end
end
