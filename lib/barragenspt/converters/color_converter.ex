defmodule Barragenspt.Converters.ColorConverter do
  use Nebulex.Caching
  alias Barragenspt.Hydrometrics.LegendMapping
  alias Barragenspt.Repo
  alias Barragenspt.Cache
  import Ecto.Query

  @ttl :timer.hours(720)

  @decorate cacheable(
              cache: Cache,
              key: "legend_mapping_#{meteo_index}_#{color_xyz}",
              ttl: @ttl
            )
  def get_hex_color(meteo_index, color_xyz) do
    query =
      from(d in LegendMapping,
        where:
          d.color_xyz == ^color_xyz and
            d.meteo_index == ^meteo_index
      )

    query
    |> Repo.all()
    |> List.first()
    |> Map.get(:color_hex)
  end
end
