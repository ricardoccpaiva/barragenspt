defmodule BarragensptWeb.HomepageV2Live.DamCardComponent do
  use BarragensptWeb, :live_component
  alias Barragenspt.Hydrometrics.{DamChartSeries, Dams}

  @impl true
  def update(assigns, socket) do
    default_tab = if assigns[:has_realtime_data], do: "realtime", else: "chart"

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:dam_card_tab, fn -> default_tab end)
      |> assign_new(:dam_month_change_label, fn -> "n/a" end)
      |> assign_new(:dam_year_change_label, fn -> "n/a" end)
      |> assign_new(:dam_month_trend_badge_class, fn -> "bg-slate-100 text-slate-600" end)
      |> assign_new(:dam_year_trend_badge_class, fn -> "bg-slate-100 text-slate-600" end)

    {:ok, socket}
  end

  @impl true
  def handle_event("dam_card_tab", %{"tab" => tab}, socket) do
    socket =
      socket
      |> assign(:dam_card_tab, tab)
      |> then(fn s ->
        if tab == "realtime" do
          series = Dams.realtime_series(s.assigns.dam.site_id)
          push_event(s, "dam_realtime_chart", %{rows: series})
        else
          s
        end
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("dam_change_window", %{"value" => value}, socket) do
    socket =
      if DamChartSeries.valid_period?(value) do
        id = socket.assigns.dam.site_id
        storage = DamChartSeries.storage_series(id, value)
        discharge = DamChartSeries.discharge_series(id, value)

        socket
        |> push_event("dam_chart_series", %{series: storage, merge: true})
        |> push_event("dam_discharge_series", %{series: discharge, merge: true})
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section id="damCard" class="fixed bottom-2 right-2 z-40 w-[360px]">
      <div class="w-full max-w-[360px] bg-slate-100/80 dark:bg-slate-800/70 backdrop-blur-md rounded-2xl shadow-float border border-slate-200/50 dark:border-slate-600/60 overflow-hidden text-[13px] text-slate-800 dark:text-slate-200">
        <div class="h-12 px-4 rounded-t-2xl flex items-center justify-between bg-slate-800 border-b border-slate-800 text-white">
          <div>
            <p class="text-sm font-semibold">
              {@dam.site_name}
            </p>
            <p class="text-xs text-slate-300">Bacia do {@dam.basin_name}</p>
          </div>
          <div class="flex items-center gap-1">
            <button
              id="export-dam-card-btn"
              type="button"
              phx-hook="ExportDamCard"
              data-dam-name={@dam.site_name}
              aria-label="Exportar card como imagem"
              class="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-700/80 transition-colors"
              title="Exportar card como imagem"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
              </svg>
            </button>
            <a
              href={if @basin_id, do: ~p"/basins/#{@basin_id}", else: ~p"/"}
              data-phx-link="patch"
              data-phx-link-state="push"
              class="text-xs text-slate-400 hover:text-white"
            >
              Fechar
            </a>
          </div>
        </div>
        <div class="p-3 space-y-2 text-sm text-slate-600 dark:text-slate-300">
          <% pct_rounded = @current_capacity && Decimal.round(@current_capacity, 2) %>
          <% pct_float = pct_rounded && Decimal.to_float(pct_rounded) %>
          <% pct_label = if pct_float, do: "#{:erlang.float_to_binary(pct_float, decimals: 2)}%", else: "n/a" %>
          <div class="flex flex-col gap-1">
            <div class="flex items-start gap-2">
              <p class="text-2xl font-bold text-slate-900 dark:text-slate-100 tabular-nums">
                {pct_label}
              </p>
              <span class="text-[10px] uppercase tracking-[0.15em] text-slate-500 dark:text-slate-400">Atual</span>
            </div>
            <div
              class="h-1.5 rounded-full bg-slate-200 dark:bg-slate-600 overflow-hidden"
              role="progressbar"
              aria-valuenow={pct_float}
              aria-valuemin="0"
              aria-valuemax="100"
              aria-label="Enchimento atual"
            >
              <div class="h-full bg-brand-500 rounded-full transition-[width] duration-300" style={"width: #{pct_float || 0}%"}></div>
            </div>
            <div class="flex flex-wrap gap-1 mt-1.5">
              <span
                class={"inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium border border-slate-200/80 dark:border-slate-500/80 #{@dam_month_trend_badge_class}"}
                aria-label={"Há 1 mês: #{@dam_month_change_label}"}
              >
                Há 1 mês: {@dam_month_change_label}
              </span>
              <span
                class={"inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium border border-slate-200/80 dark:border-slate-500/80 #{@dam_year_trend_badge_class}"}
                aria-label={"Há 1 ano: #{@dam_year_change_label}"}
              >
                Há 1 ano: {@dam_year_change_label}
              </span>
            </div>
          </div>

          <div class="grid grid-cols-2 gap-1.5">
            <div class="rounded-lg bg-white dark:bg-slate-700/80 border border-slate-200 dark:border-slate-600 px-3 py-2 flex items-center justify-between gap-2 min-h-[40px]">
              <p class="text-[10px] text-slate-500 dark:text-slate-400 uppercase tracking-wider font-medium shrink-0">Volume</p>
              <p class="text-sm font-bold text-slate-800 dark:text-slate-200 tabular-nums text-right whitespace-nowrap">
                <span>{@dam_storage_hm3 || "—"}</span>
                <span class="text-[10px] font-normal text-slate-500 dark:text-slate-400">hm³</span>
              </p>
            </div>
            <div class="rounded-lg bg-white dark:bg-slate-700/80 border border-slate-200 dark:border-slate-600 px-3 py-2 flex items-center justify-between gap-2 min-h-[40px]">
              <p class="text-[10px] text-slate-500 dark:text-slate-400 uppercase tracking-wider font-medium shrink-0">Cota</p>
              <p class="text-sm font-bold text-slate-800 dark:text-slate-200 tabular-nums text-right">
                {if @last_elevation, do: "#{@last_elevation} m", else: "—"}
              </p>
            </div>
          </div>

          <p class="text-[10px] text-slate-500 dark:text-slate-400">
            Atualizado em
            <span class="tabular-nums">
              {@last_data_point || @last_elevation_date || "—"}
            </span>
          </p>

          <div class="pt-0.5">
            <div class="inline-flex rounded-full bg-slate-200/80 p-0.5 text-xs font-medium text-slate-600">
              <%= if @has_realtime_data do %>
                <button
                  type="button"
                  phx-target={@myself}
                  phx-click="dam_card_tab"
                  phx-value-tab="realtime"
                  class={[
                    "rounded-full px-2.5 py-0.5",
                    @dam_card_tab == "realtime" && "bg-slate-50 text-slate-700 shadow-sm"
                  ]}
                >
                  Realtime
                </button>
              <% end %>
              <button
                type="button"
                phx-target={@myself}
                phx-click="dam_card_tab"
                phx-value-tab="chart"
                class={[
                  "rounded-full px-2.5 py-0.5",
                  @dam_card_tab == "chart" && "bg-slate-50 text-slate-700 shadow-sm"
                ]}
              >
                Armazenamento
              </button>
              <button
                type="button"
                phx-target={@myself}
                phx-click="dam_card_tab"
                phx-value-tab="discharge"
                class={[
                  "rounded-full px-2.5 py-0.5",
                  @dam_card_tab == "discharge" && "bg-slate-50 text-slate-700 shadow-sm"
                ]}
              >
                Caudais
              </button>
              <button
                type="button"
                phx-target={@myself}
                phx-click="dam_card_tab"
                phx-value-tab="metadata"
                class={[
                  "rounded-full px-2.5 py-0.5",
                  @dam_card_tab == "metadata" && "bg-slate-50 text-slate-700 shadow-sm"
                ]}
              >
                Info
              </button>
            </div>
          </div>

          <div
            :if={@dam_card_tab == "chart"}
            id="dam-chart-tab"
            class="pt-1.5 space-y-1.5"
            phx-hook="DamChartMount"
          >
            <div class="flex justify-between items-center">
              <span class="text-xs font-medium text-slate-600 dark:text-slate-300">Armazenamento</span>
              <div class="border border-slate-200 dark:border-slate-500 rounded-lg pl-2 pr-2.5 py-1 bg-slate-50 dark:bg-slate-600 min-w-0">
                <select
                  id="timeWindow"
                  phx-target={@myself}
                  phx-hook="DamChartTimeWindow"
                  class="text-xs w-full min-w-0 border-0 bg-transparent py-0 pr-5 text-slate-800 dark:text-slate-200 focus:ring-0 focus:outline-none cursor-pointer"
                >
                  <option value="d7">1 semana</option>
                  <option value="d14">2 semanas</option>
                  <option value="d30">1 mês</option>
                  <option value="d60" selected>2 meses</option>
                  <option value="d180">6 meses</option>
                  <option value="y2">2 anos</option>
                  <option value="y5">5 anos</option>
                  <option value="y10">10 anos</option>
                  <option value="ymax">Sem limite</option>
                </select>
              </div>
            </div>
            <div class="h-36 rounded-lg bg-white/90 dark:bg-slate-700/80 border border-slate-200/80 dark:border-slate-600 overflow-hidden">
              <canvas id="damChart"></canvas>
            </div>
            <ul class="text-[10px] text-slate-500 dark:text-slate-400 mt-0.5 list-none space-y-0.5">
              <li class="inline-flex items-center gap-1">
                <span class="w-1.5 h-1.5 rounded-full bg-brand-500 shrink-0"></span>Valores observados (%)
              </li>
              <li class="inline-flex items-center gap-1">
                <span class="w-1.5 h-1.5 rounded-full bg-amber-500 shrink-0"></span>Média histórica (%)
              </li>
            </ul>
          </div>

          <div
            :if={@dam_card_tab == "discharge"}
            id="dam-discharge-tab"
            class="pt-1.5 space-y-1.5"
            phx-hook="DischargeChartMount"
          >
            <div class="flex justify-between items-center">
              <span class="text-xs font-medium text-slate-600 dark:text-slate-300">Caudais</span>
              <div class="border border-slate-200 dark:border-slate-500 rounded-lg pl-2 pr-2.5 py-1 bg-slate-50 dark:bg-slate-600 min-w-0">
                <select
                  id="dischargeTimeWindow"
                  phx-target={@myself}
                  phx-hook="DamChartTimeWindow"
                  class="text-xs w-full min-w-0 border-0 bg-transparent py-0 pr-5 text-slate-800 dark:text-slate-200 focus:ring-0 focus:outline-none cursor-pointer"
                >
                  <option value="d7">1 semana</option>
                  <option value="d14">2 semanas</option>
                  <option value="d30">1 mês</option>
                  <option value="d60" selected>2 meses</option>
                  <option value="d180">6 meses</option>
                  <option value="y2">2 anos</option>
                  <option value="y5">5 anos</option>
                  <option value="y10">10 anos</option>
                  <option value="ymax">Sem limite</option>
                </select>
              </div>
            </div>
            <div class="h-36 rounded-lg bg-white/90 dark:bg-slate-700/80 border border-slate-200/80 dark:border-slate-600 overflow-hidden">
              <canvas id="damDischargeChart"></canvas>
            </div>
            <ul class="text-[10px] text-slate-500 dark:text-slate-400 mt-0.5 list-none space-y-0.5">
              <li class="inline-flex items-center gap-1">
                <span class="w-1.5 h-1.5 rounded-full bg-brand-500 shrink-0"></span>Caudal descarregado médio diário
              </li>
              <li class="inline-flex items-center gap-1">
                <span class="w-1.5 h-1.5 rounded-full bg-amber-500 shrink-0"></span>Caudal afluente médio diário
              </li>
              <li class="inline-flex items-center gap-1">
                <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 shrink-0"></span>Caudal efluente médio diário
              </li>
              <li class="inline-flex items-center gap-1">
                <span class="w-1.5 h-1.5 rounded-full bg-violet-500 shrink-0"></span>Caudal turbinado médio diário
              </li>
            </ul>
          </div>

          <div
            :if={@has_realtime_data && @dam_card_tab == "realtime"}
            id="dam-realtime-tab"
            class="pt-1.5 space-y-1.5"
            phx-hook="DamRealtimeChartMount"
          >
            <span class="text-xs font-medium text-slate-600 dark:text-slate-300">Dados em tempo real</span>
            <div phx-update="ignore" id="dam-realtime-chart-container">
              <div
                class="rounded-lg bg-white/90 dark:bg-slate-700/80 border border-slate-200/80 dark:border-slate-600 overflow-hidden"
                style="height: 180px;"
              >
                <canvas id="damRealtimeChart"></canvas>
              </div>
              <ul class="text-[10px] text-slate-500 dark:text-slate-400 mt-1 list-none space-y-0.5">
                <li class="inline-flex items-center gap-1">
                  <span
                    class="w-1.5 h-1.5 rounded-full shrink-0"
                    style="background-color: #0ea5e9"
                  ></span>Volume armazenado (%)
                </li>
                <li class="inline-flex items-center gap-1">
                  <span
                    class="w-1.5 h-1.5 rounded-full shrink-0"
                    style="background-color: #10b981"
                  ></span>Caudal efluente
                </li>
                <li class="inline-flex items-center gap-1">
                  <span
                    class="w-1.5 h-1.5 rounded-full shrink-0"
                    style="background-color: #8b5cf6"
                  ></span>Caudal afluente
                </li>
              </ul>
            </div>
          </div>

          <div :if={@dam_card_tab == "metadata"} class="pt-1.5">
            <div class="max-h-[36vh] overflow-y-auto rounded-lg bg-slate-100/80 border border-slate-200/80 text-[13px]">
              <%= for {section_name, fields} <- Map.get(@dam, :metadata, %{}) || %{}, is_map(fields) do %>
                <div class="px-3 py-2 border-b border-slate-200/80 last:border-b-0">
                  <p class="text-sm font-bold text-slate-900 mb-2">
                    {section_name}
                  </p>
                  <dl class="space-y-1.5 text-slate-600">
                    <%= for {k, v} <- fields do %>
                      <% val =
                        if is_binary(v),
                          do: v |> String.trim("\"") |> String.trim(",") |> String.trim(),
                          else: inspect(v) %>
                      <div>
                        <span class="font-semibold text-slate-800">
                          {k}:
                        </span>
                        <span class="text-slate-600">
                          {val}
                        </span>
                      </div>
                    <% end %>
                  </dl>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
