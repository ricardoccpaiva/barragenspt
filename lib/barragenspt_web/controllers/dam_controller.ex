defmodule BarragensptWeb.DamController do
  use BarragensptWeb, :controller
  alias Barragenspt.Geo.Coordinates
  alias Barragenspt.Hydrometrics.Dams

  def index(conn, params) do
    dams =
      params
      |> Map.get("usage_types", "")
      |> String.split(",")
      |> Enum.reject(fn usage -> usage == "" end)
      |> Dams.current_storage()
      |> Enum.map(fn d -> Coordinates.from_dam(d.site_id) end)

    render(conn, "index.json", dams: dams)
  end
end
