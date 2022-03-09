defmodule BarragensPt.Hydrometrics.Dams do
  import Ecto.Query
  alias Barragenspt.Hydrometrics.Dam
  alias Barragenspt.Geo.Coordinates

  def bounding_box(basin_id) do
    query = from d in Dam, where: d.basin_id == ^basin_id

    query
    |> Barragenspt.Repo.all()
    |> Enum.map(fn dam -> Coordinates.from_dam(dam) end)
    |> Enum.map(fn %{lat: lat, lon: lon} -> [lon, lat] end)
    |> Geocalc.bounding_box_for_points()
  end
end
