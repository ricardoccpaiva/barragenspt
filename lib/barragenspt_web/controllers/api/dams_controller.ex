defmodule BarragensptWeb.Api.DamsController do
  use BarragensptWeb, :controller
  alias Barragenspt.Hydrometrics.Dams
  use OpenApiSpex.ControllerSpecs

  alias BarragensptWeb.Api.Schemas.{
    ApiErrorResponse,
    DamCollectionResponse,
    DamInfoResponse,
    DamRealtimeResponse,
    DamSnapshotResponse
  }

  tags(["Barragens"])

  operation(:index,
    summary: "Listar barragens",
    description:
      "Lista leve de barragens com metadados de identificação e coordenadas para consumo cartográfico. Autenticação: `Authorization: Bearer <YOUR_API_TOKEN>`.",
    responses: [
      ok: {"Lista de barragens", "application/json", DamCollectionResponse},
      unauthorized: {"Token em falta/inválido", "application/json", ApiErrorResponse}
    ]
  )

  def index(conn, _params) do
    dams = Dams.all()

    conn
    |> put_view(BarragensptWeb.Api.DamsView)
    |> render("index.json", dams: dams)
  end

  operation(:info,
    summary: "Obter informação descritiva da barragem",
    description:
      "Informação descritiva da barragem de acordo com o portal SNIRH. Autenticação: `Authorization: Bearer <YOUR_API_TOKEN>`.",
    parameters: [
      id: [
        in: :path,
        description: "Identificador de site da barragem (SNIRH)",
        type: :string,
        example: "1627743384"
      ]
    ],
    responses: [
      ok: {"Metadados da barragem", "application/json", DamInfoResponse},
      unauthorized: {"Token em falta/inválido", "application/json", ApiErrorResponse}
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
      "Últimos valores de armazenamento e quota conhecidos para a janela corrente; 404 se não existir linha hidrométrica. Autenticação: `Authorization: Bearer <YOUR_API_TOKEN>`.",
    parameters: [
      id: [
        in: :path,
        description: "Identificador de site da barragem (SNIRH)",
        type: :string,
        example: "1627743384"
      ]
    ],
    responses: [
      ok: {"Instantâneo da barragem", "application/json", DamSnapshotResponse},
      unauthorized: {"Token em falta/inválido", "application/json", ApiErrorResponse}
    ]
  )

  operation(:realtime,
    summary: "Obter série realtime da barragem",
    description:
      "Série cronológica de leituras em tempo real da barragem, agrupadas por instante de recolha. Autenticação: `Authorization: Bearer <YOUR_API_TOKEN>`.",
    parameters: [
      id: [
        in: :path,
        description: "Identificador de site da barragem (SNIRH)",
        type: :string,
        example: "1627743384"
      ],
      limit: [
        in: :query,
        description: "Número máximo de instantes realtime a devolver, a contar do mais recente.",
        type: :integer,
        required: false,
        example: 24
      ]
    ],
    responses: [
      ok: {"Série realtime da barragem", "application/json", DamRealtimeResponse},
      unauthorized: {"Token em falta/inválido", "application/json", ApiErrorResponse}
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

  def realtime(conn, %{"id" => site_id} = params) do
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
        rows =
          site_id
          |> Dams.realtime_series()
          |> maybe_limit_realtime(params["limit"])

        if rows == [] do
          conn
          |> put_status(:not_found)
          |> json(%{
            errors: [
              %{
                title: "Not Found",
                detail: "No realtime data for this dam"
              }
            ]
          })
        else
          conn
          |> put_view(BarragensptWeb.Api.DamsView)
          |> render("realtime.json", dam: dam, rows: rows, limit: parse_limit(params["limit"]))
        end
    end
  end

  defp maybe_limit_realtime(rows, nil), do: rows

  defp maybe_limit_realtime(rows, limit) do
    case parse_limit(limit) do
      nil -> rows
      n -> Enum.take(rows, -n)
    end
  end

  defp parse_limit(limit) when is_integer(limit) and limit > 0, do: limit

  defp parse_limit(limit) when is_binary(limit) do
    case Integer.parse(limit) do
      {n, ""} when n > 0 -> n
      _ -> nil
    end
  end

  defp parse_limit(_), do: nil
end
