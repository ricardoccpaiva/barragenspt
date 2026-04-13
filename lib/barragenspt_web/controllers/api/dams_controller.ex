defmodule BarragensptWeb.Api.DamsController do
  use BarragensptWeb, :controller
  alias Barragenspt.Hydrometrics.Dams
  use OpenApiSpex.ControllerSpecs
  alias BarragensptWeb.Api.Schemas.{DamInfoResponse, DamSnapshotResponse}

  tags(["dams"])
  security([%{}, %{"info" => ["dams:read"]}])

  operation(:info,
    summary: "Get dam metadata",
    parameters: [
      id: [in: :path, description: "Dam ID", type: :string, example: "1627743384"]
    ],
    responses: [
      ok: {"Dam info response", "application/json", DamInfoResponse}
    ]
  )

  def info(conn, %{"id" => site_id}) do
    case Dams.get(site_id) do
      nil ->
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

      dam ->
        conn
        |> put_view(BarragensptWeb.Api.DamsView)
        |> render("info.json", dam: dam)
    end
  end

  operation(:show,
    summary: "Get dam snapshot",
    parameters: [
      id: [in: :path, description: "Dam ID", type: :string, example: "1627743384"]
    ],
    responses: [
      ok: {"Dam info response", "application/json", DamSnapshotResponse}
    ]
  )

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
