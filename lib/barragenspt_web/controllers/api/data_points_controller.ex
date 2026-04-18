defmodule BarragensptWeb.Api.DataPointsController do
  use BarragensptWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Barragenspt.Hydrometrics.{Dams, DataPointParams}

  alias BarragensptWeb.Api.Schemas.{
    ApiErrorResponse,
    DataPointParamCatalogResponse,
    DataPointsIndexResponse
  }

  tags(["Pontos de dados"])
  security([%{}, %{"info" => ["basins"]}])

  operation(:index,
    summary: "Listar leituras de parâmetros hidrométricos.",
    description: """
    Lista paginada de leituras de parâmetro hidrométricos com suporte para paginação e filtragem.

    Se usar apenas `basin_id`, é obrigatório indicar também um intervalo de datas em `colected_at[...]`
    ou combinar com `param_id` ou `site_id` (evita consultas demasiado amplas).
    """,
    parameters: [
      page: [
        in: :query,
        description: "Número da página.",
        schema: %OpenApiSpex.Schema{type: :integer, minimum: 1},
        example: 1
      ],
      per_page: [
        in: :query,
        description: "Número de leituras por página.",
        schema: %OpenApiSpex.Schema{type: :integer, minimum: 1},
        example: 20
      ],
      "colected_at[operator]": [
        in: :query,
        required: false,
        description:
          "Filtrar pela data da leitura. Suporta vários tipos de comparação: gt (maior), gte (maior ou igual), lt (menor), lte (menor ou igual). A data deve ser especificada no formato ISO8601).",
        schema: %OpenApiSpex.Schema{type: :string, format: :"date-time"}
      ],
      param_id: [
        in: :query,
        required: false,
        description: "Filtrar por identificador do parâmetro.",
        schema: %OpenApiSpex.Schema{type: :string}
      ],
      basin_id: [
        in: :query,
        required: false,
        description:
          "Filtrar por id da bacia hidrográfica. Não pode ser o único filtro: combine com `colected_at[gte]`/`colected_at[lte]` ou com `param_id` / `site_id`.",
        schema: %OpenApiSpex.Schema{type: :string}
      ],
      site_id: [
        in: :query,
        required: false,
        description: "Filtrar por identificador da barragem.",
        schema: %OpenApiSpex.Schema{type: :string}
      ]
    ],
    responses: [
      ok: {"Lista de leituras.", "application/json", DataPointsIndexResponse},
      bad_request: {"Filtros inválidos", "application/json", ApiErrorResponse},
      not_found: {"Recolha não encontrada", "application/json", ApiErrorResponse}
    ]
  )

  operation(:param_catalog,
    summary: "List de parâmetros hidrométricos",
    description:
      "Devolve o catálogo canónico SNIRH: `id`, `slug` (`param_name`) e descrição em português para cada parâmetro suportado na API e na ingestão.",
    responses: [
      ok: {"Catálogo de parâmetros", "application/json", DataPointParamCatalogResponse}
    ]
  )

  def index(conn, params) do
    case Dams.list_data_points_api(params) do
      {:ok, {rows, meta}} ->
        conn
        |> put_view(BarragensptWeb.Api.DataPointsView)
        |> render("index.json", rows: rows, meta: meta)

      {:error, %Flop.Meta{} = meta} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          errors: [
            %{
              title: "Bad Request",
              detail: flop_meta_error_detail(meta)
            }
          ]
        })
    end
  end

  def param_catalog(conn, _params) do
    json(conn, %{data: DataPointParams.all()})
  end

  defp flop_meta_error_detail(%Flop.Meta{errors: errors}) when errors == [] do
    "Invalid pagination or filter parameters."
  end

  defp flop_meta_error_detail(%Flop.Meta{errors: errors}) do
    errors
    |> Enum.map(fn {field, msgs} ->
      msgs = List.wrap(msgs)
      "#{field}: #{Enum.join(Enum.map(msgs, &inspect/1), ", ")}"
    end)
    |> Enum.join(" ")
  end
end
