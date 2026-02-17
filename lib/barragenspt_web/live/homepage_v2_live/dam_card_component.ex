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
      <div class="w-full max-w-[360px] bg-white/95 rounded-2xl shadow-float border border-slate-200 overflow-hidden text-[13px]">
        <div class="h-12 px-4 rounded-t-2xl flex items-center justify-between bg-slate-100/95 border-b border-slate-200/70">
          <div>
            <p class="text-sm font-semibold text-slate-900">
              {@dam.site_name}
            </p>
            <p class="text-xs text-slate-500">Bacia do {@dam.basin_name}</p>
          </div>
          <a
            href={if @basin_id, do: ~p"/basins/#{@basin_id}", else: ~p"/"}
            data-phx-link="patch"
            data-phx-link-state="push"
            class="text-xs text-slate-500 hover:text-slate-700"
          >
            Fechar
          </a>
        </div>
        <div class="p-4 space-y-3">
          <% pct = @current_capacity && Decimal.round(@current_capacity, 0) |> Decimal.to_integer() %>
          <div class="grid grid-cols-3 gap-3">
            <div class="rounded-xl bg-slate-50 border border-slate-100 py-1.5 px-3 flex flex-col items-center justify-center min-h-[52px]">
              <p class="text-[10px] text-slate-500 uppercase mb-0.5 tracking-wider">Enchimento</p>
              <div class="relative h-12 w-12">
                <svg viewBox="0 0 36 36" class="h-12 w-12 -rotate-90" aria-hidden="true">
                  <path
                    class="text-slate-200"
                    stroke="currentColor"
                    stroke-width="3"
                    fill="none"
                    d="M18 2.0845 a 15.9155 15.9155 0 1 1 0 31.831 a 15.9155 15.9155 0 1 1 0 -31.831"
                  />
                  <path
                    class="text-brand-500"
                    stroke="currentColor"
                    stroke-width="3"
                    fill="none"
                    stroke-linecap="round"
                    stroke-dasharray={"#{pct || 0}, 100"}
                    d="M18 2.0845 a 15.9155 15.9155 0 1 1 0 31.831 a 15.9155 15.9155 0 1 1 0 -31.831"
                  />
                </svg>
                <div
                  class="absolute inset-0 flex items-center justify-center text-xs font-bold text-slate-700 tabular-nums"
                  aria-label="Percentagem de enchimento"
                >
                  {if pct, do: "#{pct}%", else: "n/a"}
                </div>
              </div>
            </div>
            <div class="rounded-xl bg-slate-50 border border-slate-100 py-1.5 px-3 text-center flex flex-col justify-center min-h-[52px]">
              <p class="text-[10px] text-slate-500 uppercase mb-0.5 tracking-wider">Volume</p>
              <p class="text-base font-bold text-slate-800">
                <span class="tabular-nums">
                  {@dam_storage_hm3 || "—"}
                </span>
                <span class="text-xs font-normal text-slate-500">hm³</span>
              </p>
            </div>
            <div class="rounded-xl bg-slate-50 border border-slate-100 py-1.5 px-3 text-center flex flex-col justify-center min-h-[52px]">
              <p class="text-[10px] text-slate-500 uppercase mb-0.5 tracking-wider">Cota</p>
              <p class="text-base font-bold text-slate-800 tabular-nums">
                {if @last_elevation, do: "#{@last_elevation} m", else: "—"}
              </p>
            </div>
          </div>
          <p class="text-[10px] text-slate-500">
            Atualizado em
            <span class="tabular-nums">
              {@last_data_point || @last_elevation_date || "—"}
            </span>
          </p>

          <div class="flex flex-wrap gap-1.5">
            <span
              class={"inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium #{@dam_month_trend_badge_class}"}
              aria-label={"Há 1 mês: #{@dam_month_change_label}"}
            >
              Há 1 mês: {@dam_month_change_label}
            </span>
            <span
              class={"inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium #{@dam_year_trend_badge_class}"}
              aria-label={"Há 1 ano: #{@dam_year_change_label}"}
            >
              Há 1 ano: {@dam_year_change_label}
            </span>
          </div>

          <div class="pt-1">
            <div class="inline-flex rounded-full bg-slate-100 p-1 text-xs font-medium text-slate-600">
              <%= if @has_realtime_data do %>
                <button
                  type="button"
                  phx-target={@myself}
                  phx-click="dam_card_tab"
                  phx-value-tab="realtime"
                  class={[
                    "rounded-full px-3 py-1",
                    @dam_card_tab == "realtime" && "bg-white text-slate-700 shadow-sm"
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
                  "rounded-full px-3 py-1",
                  @dam_card_tab == "chart" && "bg-white text-slate-700 shadow-sm"
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
                  "rounded-full px-3 py-1",
                  @dam_card_tab == "discharge" && "bg-white text-slate-700 shadow-sm"
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
                  "rounded-full px-3 py-1",
                  @dam_card_tab == "metadata" && "bg-white text-slate-700 shadow-sm"
                ]}
              >
                Info
              </button>
            </div>
          </div>

          <div
            :if={@dam_card_tab == "chart"}
            id="dam-chart-tab"
            class="pt-2 space-y-2"
            phx-hook="DamChartMount"
          >
            <div class="flex justify-between items-center">
              <span class="text-xs font-medium text-slate-600">Armazenamento</span>
              <select
                id="timeWindow"
                phx-target={@myself}
                phx-hook="DamChartTimeWindow"
                class="text-xs border border-slate-200 rounded-lg px-2 py-1 bg-white"
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
            <div class="h-48 rounded-xl bg-slate-50 border border-slate-100 overflow-hidden">
              <canvas id="damChart"></canvas>
            </div>
            <ul class="text-[10px] text-slate-500 mt-1 list-none space-y-0.5">
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
            class="pt-2 space-y-2"
            phx-hook="DischargeChartMount"
          >
            <div class="flex justify-between items-center">
              <span class="text-xs font-medium text-slate-600">Caudais</span>
              <select
                id="dischargeTimeWindow"
                phx-target={@myself}
                phx-hook="DamChartTimeWindow"
                class="text-xs border border-slate-200 rounded-lg px-2 py-1 bg-white"
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
            <div class="h-48 rounded-xl bg-slate-50 border border-slate-100 overflow-hidden">
              <canvas id="damDischargeChart"></canvas>
            </div>
            <ul class="text-[10px] text-slate-500 mt-1 list-none space-y-0.5">
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
            class="pt-2 space-y-2"
            phx-hook="DamRealtimeChartMount"
          >
            <span class="text-xs font-medium text-slate-600">Dados em tempo real</span>
            <div phx-update="ignore" id="dam-realtime-chart-container">
              <div
                class="rounded-xl bg-white border border-slate-100 overflow-hidden"
                style="height: 240px;"
              >
                <canvas id="damRealtimeChart"></canvas>
              </div>
              <ul class="text-[10px] text-slate-500 mt-1 list-none space-y-0.5">
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

          <div :if={@dam_card_tab == "metadata"} class="pt-2">
            <div class="max-h-[42vh] overflow-y-auto rounded-xl bg-white border border-slate-100 text-[13px]">
              <%= for {section_name, fields} <- Map.get(@dam, :metadata, %{}) || %{}, is_map(fields) do %>
                <div class="px-4 py-3 border-b border-slate-100 last:border-b-0">
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
