defmodule BarragensptWeb.Api.BasinsController do
  use BarragensptWeb, :controller

  alias Barragenspt.Hydrometrics.Basins

  def index(conn, _params) do
    basins = Basins.summary_stats([])

    conn
    |> put_view(BarragensptWeb.Api.BasinsView)
    |> render("index.json", basins: basins)
  end
end
