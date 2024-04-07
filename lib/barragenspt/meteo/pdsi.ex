defmodule Barragenspt.Meteo.Pdsi do
  import Ecto.Query
  use Nebulex.Caching
  alias Barragenspt.MeteoDataCache, as: Cache
  alias Barragenspt.Repo
  alias Barragenspt.Models.Meteo.{SvgArea, PdsiValue, LegendMapping}

  @decorate cacheable(
              cache: Cache,
              key: "pdsi_data_by_scale_#{year}",
              ttl: 99_999_999
            )
  def get_pdsi_data_by_scale(year) do
    query =
      from pdv in PdsiValue,
        join: sa in SvgArea,
        on: pdv.svg_path_hash == sa.svg_path_hash,
        join: plm in LegendMapping,
        on:
          pdv.color_hex == plm.color_hex and
            pdv.geographic_area_type == sa.geographic_area_type,
        where:
          plm.meteo_index == "pdsi" and pdv.year == ^year and
            sa.geographic_area_type ==
              ^"municipality",
        group_by: [pdv.year, pdv.month, pdv.color_hex],
        order_by: [asc: pdv.year, asc: pdv.month],
        select: %{
          count: count(1),
          year: pdv.year,
          month: pdv.month,
          color_hex: pdv.color_hex,
          weight: sum(sa.area) / 150_488.279829928717369 * 100
        }

    Repo.all(query)
  end
end
