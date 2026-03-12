defmodule Barragenspt.Converters.ColorConverter do
  use Nebulex.Caching
  alias Barragenspt.Models.Meteo.LegendMapping
  alias Barragenspt.Repo
  alias Barragenspt.Cache
  import Ecto.Query

  def get_hex_color(meteo_index, color_xyz, variant \\ nil)

  def get_hex_color(_mi, "rgb(100%,100%,100%)", _variant) do
    "#FFFFFF"
  end

  @decorate cacheable(
              cache: Cache,
              key: "legend_mapping_#{meteo_index}_#{color_xyz}",
              ttl: :timer.hours(720)
            )
  def get_hex_color(meteo_index, color_xyz, nil) do
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

  @decorate cacheable(
              cache: Cache,
              key: "legend_mapping_#{meteo_index}_#{color_xyz}_#{variant}",
              ttl: :timer.hours(720)
            )
  def get_hex_color(meteo_index, color_xyz, variant) do
    query =
      from(d in LegendMapping,
        where:
          d.color_xyz == ^color_xyz and
            d.meteo_index == ^meteo_index and d.variant == ^variant
      )

    query
    |> Repo.all()
    |> List.first()
    |> Map.get(:color_hex)
  end
end
