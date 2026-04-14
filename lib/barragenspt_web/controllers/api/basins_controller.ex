defmodule BarragensptWeb.Api.BasinsController do
  use BarragensptWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Barragenspt.Hydrometrics.{Basins, Dams}

  alias BarragensptWeb.Api.Schemas.{
    BasinDamListResponse,
    BasinDetailResponse,
    BasinListResponse,
    DamSnapshotResponse
  }

  tags(["Bacias"])
  security([%{}, %{"info" => ["basins"]}])

  operation(:index,
    summary: "Listar bacias",
    description: "Devolve uma lista de bacias com resumo por bacia.",
    responses: [
      ok: {"Lista de bacias", "application/json", BasinListResponse}
    ]
  )

  operation(:show,
    summary: "Obter resumo de uma bacia",
    description: "Resumo de uma única bacia.",
    parameters: [
      id: [
        in: :path,
        description: "Identificador da bacia.",
        type: :string,
        example: "1"
      ]
    ],
    responses: [
      ok: {"Resumo da bacia", "application/json", BasinDetailResponse}
    ]
  )

  operation(:dams,
    summary: "Listar barragens de uma bacia",
    description: "Devolve uma lista de barragens da bacia hidrográfica com resumo por barragem.",
    parameters: [
      id: [
        in: :path,
        description: "Identificador da bacia",
        type: :string,
        example: "1"
      ]
    ],
    responses: [
      ok: {"Barragens na bacia", "application/json", BasinDamListResponse}
    ]
  )

  operation(:dam,
    summary:
      "Obter snapshot dos indicadores hidrométricos de uma barragem na bacia hidrográfica.",
    description: "Resposta equivalente à chamada `GET /basins/{id}/dams`.",
    parameters: [
      id: [
        in: :path,
        description: "Identificador da bacia",
        type: :string,
        example: "1"
      ],
      site_id: [
        in: :path,
        description: "Identificador de site da barragem (SNIRH)",
        type: :string,
        example: "1627743384"
      ]
    ],
    responses: [
      ok:
        {"Snapshot dos valores hidrométricos da barragem.", "application/json",
         DamSnapshotResponse}
    ]
  )

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
