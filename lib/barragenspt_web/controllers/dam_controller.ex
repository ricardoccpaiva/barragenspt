defmodule BarragensptWeb.DamController do
  use BarragensptWeb, :controller
  import Ecto.Query
  alias Barragenspt.Mappers.Colors
  alias Barragenspt.Geo.Coordinates

  def index(conn, _params) do
    coords =
      from(Barragenspt.Hydrometrics.Dam)
      |> Barragenspt.Repo.all()
      |> Enum.map(fn dam -> Coordinates.from_dam(dam) end)
      |> Enum.map(fn dam -> Map.put(dam, :basin_color, Colors.lookup(dam.basin_id)) end)
      |> Enum.map(fn dam -> Map.put(dam, :pct, :rand.uniform(100)) end)
      |> Enum.map(fn dam ->
        Map.put(dam, :capacity_color, Colors.lookup_capacity(dam.pct))
      end)

    render(conn, "index.json", dams: coords)
  end
end
