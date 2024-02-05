defmodule Barragenspt.Repo.Migrations.CreateSvgAreaTotalsView do
  use Ecto.Migration

  def up do
    execute """
    CREATE VIEW svg_area_totals AS
      select sum(area), geographic_area_type
      from svg_area
      group by geographic_area_type
    ;
    """
  end

  def down do
    execute "DROP VIEW svg_area_totals;"
  end
end
