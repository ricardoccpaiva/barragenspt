defmodule BarragensptWeb.DamController do
  use BarragensptWeb, :controller
  alias Barragenspt.Geo.Coordinates
  alias Barragenspt.Hydrometrics.Dams
  alias Barragenspt.Mappers.Colors

  def index(conn, params) do
    dams =
      params
      |> Map.get("usage_types", "")
      |> String.split(",")
      |> Enum.reject(fn usage -> usage == "" end)
      |> Dams.current_storage()
      |> Enum.map(fn d -> build_dam_data(d) end)

    render(conn, "index.json", dams: dams)
  end

  defp build_dam_data(dam) do
    elementary_Data = %{
      id: dam.site_id,
      basin_id: dam.basin_id,
      site_id: dam.site_id,
      current_storage: dam.current_storage,
      current_storage_color: Colors.lookup_capacity(dam.current_storage)
    }

    coordinates = Coordinates.from_dam(dam.site_id)

    Map.merge(elementary_Data, coordinates)
  end
end
