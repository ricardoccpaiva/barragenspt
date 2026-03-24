defmodule BarragensptWeb.Dashboard.DataPointsLive do
  use BarragensptWeb, :live_view

  import Flop.Phoenix

  on_mount {BarragensptWeb.UserAuth, :require_authenticated}

  alias Barragenspt.Hydrometrics.{Dams, DataPointParamLabels}

  @table_opts_base [
    container: true,
    container_attrs: [
      class:
        "overflow-x-auto rounded-xl border border-slate-200 dark:border-slate-600"
    ],
    table_attrs: [
      class: "min-w-full divide-y divide-slate-200 text-sm dark:divide-slate-600"
    ],
    thead_attrs: [class: "bg-slate-50 dark:bg-slate-800/80"],
    thead_th_attrs: [
      class: "px-4 py-3 text-left font-semibold text-slate-700 dark:text-slate-200"
    ],
    tbody_td_attrs: [
      class: "px-4 py-3 text-slate-700 tabular-nums dark:text-slate-300"
    ],
    tbody_tr_attrs: [class: "bg-white dark:bg-slate-800/40"]
  ]

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:filter_fields, filter_field_configs())
      |> assign(:table_opts, table_opts(assigns.awaiting_param_filter))

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="w-[120%] -mx-[10%] space-y-6">


        <.form
          for={@form}
          id="data-points-filter-form"
          class="rounded-lg border border-slate-200 bg-white p-2.5 dark:border-slate-600 dark:bg-slate-800 sm:p-3"
          phx-change="update-filter"
          phx-submit="update-filter"
        >
          <p class="mb-1 text-xs font-medium text-slate-500 dark:text-slate-400">
            Filtros
          </p>
          <p class="mb-2 text-xs text-slate-600 dark:text-slate-400">
            É necessário escolher um parâmetro e clicar em Aplicar para carregar a tabela.
          </p>
          <div class="flex flex-wrap items-end gap-x-2 gap-y-1">
            <.filter_fields :let={i} form={@form} fields={@filter_fields}>
              <div class="min-w-[8rem] max-w-[11rem] flex-1 basis-[9.5rem] sm:basis-[10rem] [&>div]:!mb-0 [&_label_span]:mb-0.5 [&_label_span]:text-xs [&_label_span]:font-medium">
                <%= if i.type == "select" do %>
                  <.input
                    field={i.field}
                    label={i.label}
                    type="select"
                    options={Keyword.get(i.rest, :options, [])}
                    phx-debounce="300"
                    class="block w-full rounded-md border border-slate-300 bg-white px-2 py-1 text-xs text-slate-900 shadow-sm focus:border-brand-500 focus:ring-1 focus:ring-brand-500 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100"
                    {Keyword.drop(i.rest, [:options])}
                  />
                <% else %>
                  <.input
                    field={i.field}
                    label={i.label}
                    type={i.type}
                    phx-debounce="300"
                    class="block w-full rounded-md border border-slate-300 bg-white px-2 py-1 text-xs text-slate-900 shadow-sm focus:border-brand-500 focus:ring-1 focus:ring-brand-500 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100"
                    {i.rest}
                  />
                <% end %>
              </div>
            </.filter_fields>
          </div>

          <div class="mt-2 flex flex-wrap items-center gap-2 border-t border-slate-100 pt-2 dark:border-slate-700/80">
            <button
              type="submit"
              class="inline-flex rounded-md bg-brand-600 px-2.5 py-1 text-xs font-semibold text-white hover:bg-brand-700"
            >
              Aplicar
            </button>
            <.link
              patch={~p"/dashboard/data-points"}
              class="inline-flex rounded-md border border-slate-300 px-2.5 py-1 text-xs font-semibold text-slate-700 hover:bg-slate-50 dark:border-slate-600 dark:text-slate-200 dark:hover:bg-slate-700/50"
            >
              Limpar
            </.link>
            <%= if @data_points_export_enabled do %>
              <a
                href={@data_points_export_href}
                class="inline-flex rounded-md border border-slate-300 px-2.5 py-1 text-xs font-semibold text-slate-700 hover:bg-slate-50 dark:border-slate-600 dark:text-slate-200 dark:hover:bg-slate-700/50"
              >
                Exportar CSV
              </a>
            <% else %>
              <span
                class="inline-flex cursor-not-allowed rounded-md border border-dashed border-slate-300 px-2.5 py-1 text-xs font-semibold text-slate-400 dark:border-slate-600 dark:text-slate-500"
                title="Escolha um parâmetro, aplique os filtros e volte a exportar."
              >
                Exportar CSV
              </span>
            <% end %>
          </div>
        </.form>

        <.table
          id="data-points-table"
          items={@data_points}
          meta={@meta}
          path={~p"/dashboard/data-points"}
          opts={@table_opts}
        >
          <:col :let={row} label="Barragem" field={:dam_name}>{row.dam_name}</:col>
          <:col :let={row} label="Bacia" field={:basin}>{row.basin}</:col>
          <:col :let={row} label="Parâmetro" field={:param_name}>
            {DataPointParamLabels.label(row.param_name)}
          </:col>
          <:col :let={row} label="Valor" field={:value}>{format_decimal(row.value)}</:col>
          <:col :let={row} label="Recolhido" field={:colected_at}>
            {format_naive(row.colected_at)}
          </:col>
        </.table>

        <div class="flex justify-center py-2">
          <.pagination
            meta={@meta}
            path={~p"/dashboard/data-points"}
            page_links={5}
            class="flex flex-wrap items-center justify-center gap-1"
            aria-label="Paginação"
            page_list_attrs={[
              class:
                "order-2 m-0 flex list-none flex-wrap items-center justify-center gap-1 p-0"
            ]}
            page_list_item_attrs={[
              class: "m-0 flex list-none items-center justify-center p-0"
            ]}
            page_link_attrs={flop_pagination_page_link_attrs()}
            current_page_link_attrs={flop_pagination_current_attrs()}
            disabled_link_attrs={flop_pagination_disabled_attrs()}
          >
            <:previous attrs={flop_pagination_prev_attrs()}>
              ← Anterior
            </:previous>
            <:next attrs={flop_pagination_next_attrs()}>
              Seguinte →
            </:next>
          </.pagination>
        </div>

        <.link
          navigate={~p"/dashboard"}
          class="inline-flex text-sm font-medium text-brand-600 hover:underline dark:text-brand-400"
        >
          ← Voltar ao painel
        </.link>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:data_points_export_href, ~p"/dashboard/data-points/export/csv")
     |> assign(:awaiting_param_filter, true)
     |> assign(:data_points_export_enabled, false)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    export_href = data_points_export_csv_href(params)

    case Dams.list_data_points(params) do
      {:ok, {rows, meta}} ->
        param_set? = Dams.data_points_param_name_filter_set?(meta.flop)

        {:noreply,
         socket
         |> assign(data_points: rows, meta: meta, form: to_form(meta))
         |> assign(:data_points_export_href, export_href)
         |> assign(:awaiting_param_filter, not param_set?)
         |> assign(:data_points_export_enabled, param_set?)}

      {:error, meta} ->
        {:noreply,
         socket
         |> put_flash(:error, "Parâmetros de filtro ou paginação inválidos.")
         |> assign(data_points: [], meta: meta, form: to_form(meta))
         |> assign(:data_points_export_href, export_href)
         |> assign(:awaiting_param_filter, true)
         |> assign(:data_points_export_enabled, false)}
    end
  end

  @impl true
  def handle_event("update-filter", params, socket) do
    params = Map.delete(params, "_target")
    query = Plug.Conn.Query.encode(params)

    {:noreply, push_patch(socket, to: "/dashboard/data-points?" <> query)}
  end

  defp flop_pagination_page_link_attrs do
    [
      class:
        "inline-flex min-h-8 min-w-8 shrink-0 items-center justify-center rounded-md border border-slate-200 bg-white px-2 text-xs font-medium tabular-nums text-slate-700 shadow-sm hover:bg-slate-50 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-200 dark:hover:bg-slate-700"
    ]
  end

  defp flop_pagination_current_attrs do
    [
      class:
        "inline-flex min-h-8 min-w-8 shrink-0 cursor-default items-center justify-center rounded-md border-2 border-brand-600 bg-brand-50 px-2 text-xs font-semibold tabular-nums text-brand-800 shadow-sm dark:border-brand-400 dark:bg-brand-950/50 dark:text-brand-200"
    ]
  end

  defp flop_pagination_prev_attrs do
    [
      class:
        "order-1 inline-flex min-h-8 shrink-0 items-center justify-center rounded-md border border-slate-200 bg-white px-2.5 text-xs font-medium text-slate-700 shadow-sm hover:bg-slate-50 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-200 dark:hover:bg-slate-700"
    ]
  end

  defp flop_pagination_next_attrs do
    [
      class:
        "order-3 inline-flex min-h-8 shrink-0 items-center justify-center rounded-md border border-slate-200 bg-white px-2.5 text-xs font-medium text-slate-700 shadow-sm hover:bg-slate-50 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-200 dark:hover:bg-slate-700"
    ]
  end

  defp flop_pagination_disabled_attrs do
    [
      class:
        "inline-flex min-h-8 shrink-0 cursor-not-allowed items-center justify-center rounded-md border border-transparent px-2.5 text-xs text-slate-400 dark:text-slate-500"
    ]
  end

  defp table_opts(awaiting_param?) when is_boolean(awaiting_param?) do
    no_results =
      if awaiting_param? do
        Phoenix.HTML.raw(
          "<p class=\"p-6 text-center text-sm text-slate-600 dark:text-slate-300\">Escolha um parâmetro em «Parâmetro» e clique em <span class=\"font-medium\">Aplicar</span> para ver dados.</p>"
        )
      else
        Phoenix.HTML.raw(
          "<p class=\"p-6 text-center text-sm text-slate-600 dark:text-slate-300\">Sem resultados com estes filtros.</p>"
        )
      end

    Keyword.put(@table_opts_base, :no_results_content, no_results)
  end

  defp data_points_export_csv_href(params) when is_map(params) do
    base = ~p"/dashboard/data-points/export/csv"

    case params do
      p when map_size(p) == 0 -> base
      p -> base <> "?" <> Plug.Conn.Query.encode(p)
    end
  end

  defp filter_field_configs do
    param_opts =
      Enum.map(data_point_param_names(), fn slug ->
        {DataPointParamLabels.label(slug), slug}
      end)

    [
      {:param_name,
       [
         op: :==,
         label: "Parâmetro",
         type: "select",
         options: [{"— escolher parâmetro —", ""} | param_opts]
       ]},
      {:dam_name, [op: :ilike, label: "Barragem"]},
      {:basin, [op: :ilike, label: "Bacia"]},
      {:colected_at, [op: :>=, label: "Recolhido desde (UTC)"]},
      {:colected_at, [op: :<=, label: "Recolhido até (UTC)"]}
    ]
  end

  defp format_decimal(nil), do: "—"

  defp format_decimal(%Decimal{} = d) do
    d
    |> Decimal.round(4)
    |> Decimal.to_string(:normal)
  end

  defp format_naive(nil), do: "—"
  defp format_naive(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_string(ndt)

  defp data_point_param_names do
    [
      "volume_last_hour",
      "volume_last_day_month",
      "elevation_last_hour",
      "ouput_flow_rate_daily",
      "tributary_daily_flow",
      "effluent_daily_flow",
      "turbocharged_daily_flow"
    ]
  end
end
