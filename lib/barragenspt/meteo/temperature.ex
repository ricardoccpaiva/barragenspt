defmodule Barragenspt.Meteo.Temperature do
  import Ecto.Query
  use Nebulex.Caching
  alias Barragenspt.MeteoDataCache, as: Cache
  alias Barragenspt.Repo
  alias Barragenspt.Hydrometrics.SvgArea
  alias Barragenspt.Hydrometrics.TemperatureDailyValue
  alias Barragenspt.Hydrometrics.LegendMapping

  @decorate cacheable(
              cache: Cache,
              key: "meteo_temperature_data_by_scale_#{year}_#{month}_#{layer}",
              ttl: 99_999_999
            )
  def get_data_by_scale(year, month, layer) do
    query =
      from pdv in TemperatureDailyValue,
        join: sa in SvgArea,
        on: pdv.svg_path_hash == sa.svg_path_hash,
        join: plm in LegendMapping,
        on:
          pdv.color_hex == plm.color_hex and
            pdv.geographic_area_type == sa.geographic_area_type,
        where:
          plm.meteo_index == "temperature" and pdv.layer == ^layer and
            fragment("EXTRACT(year FROM ?) = ?", pdv.date, ^year) and
            fragment("EXTRACT(month FROM ?) = ?", pdv.date, ^month) and
            sa.geographic_area_type == ^"municipality",
        group_by: [pdv.date, pdv.color_hex],
        order_by: [asc: pdv.date, asc: pdv.date],
        select: %{
          count: count(1),
          date: pdv.date,
          color_hex: pdv.color_hex,
          weight: sum(sa.area) / 64867.01067 * 100
        }

    Repo.all(query)
  end
end
