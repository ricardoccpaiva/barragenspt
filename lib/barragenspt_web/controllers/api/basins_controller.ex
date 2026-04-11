defmodule BarragensptWeb.Api.BasinsController do
  use BarragensptWeb, :controller

  alias Barragenspt.Hydrometrics.{Basins, Dams}

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

  def dams(conn, %{"id" => basin_id}) do
    case Basins.summary_stats(basin_id, []) do
      [] ->
        conn
        |> put_status(:not_found)
        |> json(%{
          errors: [%{title: "Not Found", detail: "No basin snapshot for this id"}]
        })

      dams ->
        conn
        |> put_view(BarragensptWeb.Api.BasinsView)
        |> render("dams.json", basin_id: basin_id, dams: dams)
    end
  end

  def dam(conn, %{"id" => basin_id, "site_id" => site_id}) do
    case Dams.dam_summary_stats(site_id) do
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          errors: [
            %{
              title: "Not Found",
              detail: "No dam with this site_id in this basin"
            }
          ]
        })

      {:error, :no_snapshot} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          errors: [
            %{
              title: "Not Found",
              detail: "No hydrometric snapshot for this dam in the current window"
            }
          ]
        })

      {:ok, dam} ->
        conn
        |> put_view(BarragensptWeb.Api.DamsView)
        |> render("dam.json", basin_id: basin_id, dam: dam)
    end
  end
end
