defmodule Barragenspt.Repo.Migrations.CreateMoreIpmaIndexes do
  use Ecto.Migration

  def change do
    create index("precipitation_daily_value", [:date])
    create index("precipitation_monthly_value", [:year, :month])

    create index("legend_mapping", [:color_hex])
    create index("legend_mapping", [:min_value, :max_value, :id, :meteo_index])

    create index("svg_area", [:svg_path_hash])
    create index("pdsi_value", [:svg_path_hash])
  end
end
