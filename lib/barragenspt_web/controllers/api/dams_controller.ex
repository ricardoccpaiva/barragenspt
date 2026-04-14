defmodule BarragensptWeb.Api.DamsController do
  use BarragensptWeb, :controller
  alias Barragenspt.Hydrometrics.Dams
  use OpenApiSpex.ControllerSpecs
  alias BarragensptWeb.Api.Schemas.{DamInfoResponse, DamSnapshotResponse}

  tags(["Barragens"])
  security([%{}, %{"info" => ["dams:read"]}])

  operation(:info,
    summary: "Obter informação descritiva da barragem",
    description: "Informação descritiva da barragem de acordo com o portal SNIRH.",
    parameters: [
      id: [
        in: :path,
        description: "Identificador de site da barragem (SNIRH)",
        type: :string,
        example: "1627743384"
      ]
    ],
    responses: [
      ok: {"Metadados da barragem", "application/json", DamInfoResponse}
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
    summary: "Obter snapshot dos indicadores hidrométrico da barragem.",
    description:
      "Últimos valores de armazenamento e quota conhecidos para a janela corrente; 404 se não existir linha hidrométrica.",
    parameters: [
      id: [
        in: :path,
        description: "Identificador de site da barragem (SNIRH)",
        type: :string,
        example: "1627743384"
      ]
    ],
    responses: [
      ok: {"Instantâneo da barragem", "application/json", DamSnapshotResponse}
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
