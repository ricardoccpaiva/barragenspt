defmodule Barragenspt.Repo.Migrations.CreateIpmaIndexes do
  use Ecto.Migration

  def change do
    create index("temperature_daily_value", [:date])
    create index("temperature_daily_value", [:svg_path_hash])
    create index("temperature_daily_value", [:geographic_area_type])
    create index("temperature_daily_value", [:date, :color_hex, :layer, :geographic_area_type])

    create index("svg_area", [:svg_path_hash, :geographic_area_type])

    create index("svg_area", [:geographic_area_type])

    create index("legend_mapping", [:color_hex, :meteo_index])
  end
end
