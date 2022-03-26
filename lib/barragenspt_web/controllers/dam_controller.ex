defmodule BarragensptWeb.DamController do
  use BarragensptWeb, :controller
  alias Barragenspt.Geo.Coordinates
  alias Barragenspt.Hydrometrics.Dams

  def index(conn, _params) do
    dams = Enum.map(Dams.current_storage(), fn d -> Coordinates.from_dam(d.site_id) end)

    render(conn, "index.json", dams: dams)
  end
end
