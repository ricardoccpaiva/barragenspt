defmodule BarragensptWeb.Api.BasinsController do
  use BarragensptWeb, :controller

  alias Barragenspt.Hydrometrics.Basins

  def index(conn, _params) do
    basins = Basins.summary_stats([])

    conn
    |> put_view(BarragensptWeb.Api.BasinsView)
    |> render("index.json", basins: basins)
  end

  def show(conn, %{"id" => id}) do
    case Basins.basin_summary(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{
          errors: [%{title: "Not Found", detail: "No basin snapshot for this id"}]
        })

      basin ->
        conn
        |> put_view(BarragensptWeb.Api.BasinsView)
        |> render("show.json", basin: basin)
    end
  end
end
