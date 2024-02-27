defmodule Barragenspt.Meteo.Precipitation do
  import Ecto.Query
  use Nebulex.Caching
  alias Barragenspt.Cache
  alias Barragenspt.Repo
  alias Barragenspt.Hydrometrics.SvgArea
  alias Barragenspt.Hydrometrics.PrecipitationDailyValue
  alias Barragenspt.Hydrometrics.PdsiValue
  alias Barragenspt.Hydrometrics.LegendMapping

  @decorate cacheable(
              cache: Cache,
              key: "precipitation_data_by_scale_#{year}",
              ttl: 99_999_999
            )
  def get_precipitation_data_by_scale(year) do
    query =
      from pdv in PrecipitationDailyValue,
        join: sa in SvgArea,
        on: pdv.svg_path_hash == sa.svg_path_hash,
        join: plm in LegendMapping,
        on:
          pdv.color_hex == plm.color_hex and
            pdv.geographic_area_type == sa.geographic_area_type,
        where:
          plm.meteo_index == "precipitation" and
            fragment("EXTRACT(year FROM ?) = ?", pdv.date, ^year),
        group_by: [pdv.date, pdv.color_hex],
        order_by: [asc: pdv.date, asc: pdv.date],
        select: %{
          count: count(1),
          date: pdv.date,
          color_hex: pdv.color_hex,
          weight: sum(sa.area) / 60541.204940844229249
        }

    Repo.all(query)
  end

  @decorate cacheable(
              cache: Cache,
              key: "precipitation_data_#{year}",
              ttl: 99_999_999
            )
  def get_precipitation_data(year) do
    subquery =
      from pdv in PrecipitationDailyValue,
        join: sa in SvgArea,
        on: pdv.svg_path_hash == sa.svg_path_hash,
        join: plm in LegendMapping,
        on: pdv.color_hex == plm.color_hex,
        where: plm.meteo_index == "precipitation",
        group_by: [pdv.date, pdv.color_hex, plm.max_value],
        order_by: [asc: pdv.date],
        select: %{
          count: count(1),
          date: pdv.date,
          color_hex: pdv.color_hex,
          mean_value: plm.max_value,
          weight: sum(sa.area) / 60541.204940844229249
        }

    query =
      from(c in subquery(subquery),
        group_by: c.date,
        where: fragment("EXTRACT(year FROM ?) = ?", c.date, ^year),
        select: %{
          date: c.date,
          weighted_average: sum(c.mean_value * c.weight) / sum(c.weight)
        }
      )

    Repo.all(query)
  end
end
