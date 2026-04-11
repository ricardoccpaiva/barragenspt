defmodule BarragensptWeb.Api.DamsController do
  use BarragensptWeb, :controller

  alias Barragenspt.Hydrometrics.Dams

  def show(conn, %{"id" => site_id}) do
    case Dams.dam_summary_stats(site_id) do
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          errors: [
            %{
              title: "Not Found",
              detail: "No dam with this site id"
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
        |> render("dam.json", dam: dam, scope: :global)
    end
  end
end
