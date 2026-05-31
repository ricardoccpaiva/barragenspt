defmodule BarragensptWeb.Api.BasinsController do
  use BarragensptWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Barragenspt.Hydrometrics.{Basins, Dams, EmbalsesNet}

  alias BarragensptWeb.Api.Schemas.{
    ApiErrorResponse,
    BasinDamListResponse,
    BasinDetailResponse,
    BasinListResponse,
    DamSnapshotResponse
  }

  tags(["Bacias"])

  operation(:index,
    summary: "Listar bacias",
    description:
      "Devolve uma lista de bacias com resumo por bacia. Autenticação: `Authorization: Bearer <YOUR_API_TOKEN>`.",
    parameters: [
      includeSpain: [
        in: :query,
        description:
          "Quando `true`, inclui também as bacias espanholas disponíveis no feed Embalses.net. Por omissão é `false`.",
        type: :boolean,
        required: false,
        example: false
      ]
    ],
    responses: [
      ok: {"Lista de bacias", "application/json", BasinListResponse},
      unauthorized: {"Token em falta/inválido", "application/json", ApiErrorResponse}
    ]
  )

  operation(:show,
    summary: "Obter resumo de uma bacia",
    description:
      "Resumo de uma única bacia. Autenticação: `Authorization: Bearer <YOUR_API_TOKEN>`.",
    parameters: [
      id: [
        in: :path,
        description: "Identificador da bacia.",
        type: :string,
        example: "1"
      ]
    ],
    responses: [
      ok: {"Resumo da bacia", "application/json", BasinDetailResponse},
      unauthorized: {"Token em falta/inválido", "application/json", ApiErrorResponse}
    ]
  )

  operation(:dams,
    summary: "Listar barragens de uma bacia",
    description:
      "Devolve uma lista de barragens da bacia hidrográfica com resumo por barragem. Autenticação: `Authorization: Bearer <YOUR_API_TOKEN>`.",
    parameters: [
      id: [
        in: :path,
        description: "Identificador da bacia",
        type: :string,
        example: "1"
      ]
    ],
    responses: [
      ok: {"Barragens na bacia", "application/json", BasinDamListResponse},
      unauthorized: {"Token em falta/inválido", "application/json", ApiErrorResponse}
    ]
  )

  operation(:dam,
    summary:
      "Obter snapshot dos indicadores hidrométricos de uma barragem na bacia hidrográfica.",
    description:
      "Resposta equivalente à chamada `GET /basins/{id}/dams`. Autenticação: `Authorization: Bearer <YOUR_API_TOKEN>`.",
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
         DamSnapshotResponse},
      unauthorized: {"Token em falta/inválido", "application/json", ApiErrorResponse}
    ]
  )

  def index(conn, params) do
    include_spain = truthy_param?(params["includeSpain"])

    basins =
      Basins.summary_stats([])
      |> maybe_include_spain(include_spain)

    conn
    |> put_view(BarragensptWeb.Api.BasinsView)
    |> render("index.json", basins: basins, include_spain: include_spain)
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

  defp maybe_include_spain(basins, false), do: basins

  defp maybe_include_spain(basins, true) do
    basins ++
      Enum.map(EmbalsesNet.basins_info(), fn basin ->
        %{
          id: basin.id,
          name: basin.basin_name,
          country: "es",
          current_storage_percent: parse_percent(basin.current_pct),
          current_storage_volume: nil,
          historical_average_volume: nil,
          total_capacity: nil
        }
      end)
  end

  defp truthy_param?(value) when value in [true, "true", "1", 1, "yes", "on"], do: true
  defp truthy_param?(_), do: false

  defp parse_percent(value) when is_number(value), do: value * 1.0

  defp parse_percent(value) when is_binary(value) do
    case Float.parse(String.replace(value, ",", ".")) do
      {num, _} -> num
      :error -> nil
    end
  end

  defp parse_percent(_), do: nil
end
