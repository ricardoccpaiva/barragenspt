defmodule BarragensptWeb.HomepageV2Live.BasinCardComponent do
  use BarragensptWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <section id="basinInfoPanel" class="fixed bottom-2 right-2 z-40 w-[360px]">
      <div class="bg-white/95 rounded-2xl shadow-float border border-slate-200 overflow-hidden text-[13px]">
        <div
          class="h-14 px-4 rounded-t-2xl flex items-center justify-between border-b border-slate-200/70"
          style="background-color: #F2F2F2"
        >
          <div>
            <p class="text-sm font-semibold text-slate-900">
              {@basin_card.name}
            </p>
          </div>
          <a
            href="/"
            data-phx-link="patch"
            data-phx-link-state="push"
            class="text-xs text-slate-500 hover:text-slate-700"
          >
            Fechar
          </a>
        </div>
        <div class="p-4 space-y-3 text-sm text-slate-600">
          <div class="flex flex-col gap-1.5">
            <div class="flex items-start gap-2">
              <p class="text-3xl font-bold text-slate-900 tabular-nums">
                {if @basin_card.avg_observed, do: "#{@basin_card.avg_observed}%", else: "n/a"}
              </p>
              <span class="text-[10px] uppercase tracking-[0.15em] text-slate-500">Atual</span>
            </div>
            <p class="text-xs text-slate-500">
              Volume armazenado:
              <span class="font-medium text-slate-700 tabular-nums">
                {@basin_card.total_storage_label}
              </span>
            </p>
            <div
              class="h-2 rounded-full bg-slate-100 overflow-hidden"
              role="progressbar"
              aria-valuenow={@basin_card.avg_observed}
              aria-valuemin="0"
              aria-valuemax="100"
              aria-label="Enchimento atual"
            >
              <div
                class="h-full bg-brand-500 rounded-full transition-[width] duration-300"
                style={"width: #{@basin_card.avg_observed || 0}%"}
              >
              </div>
            </div>
            <div class="flex flex-wrap gap-1.5">
              <span
                class={"inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium #{@basin_card.month_trend_badge_class}"}
                aria-label={"Há 1 mês: #{@basin_card.month_change_label}"}
              >
                Há 1 mês: {@basin_card.month_change_label}
              </span>
              <span
                class={"inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium #{@basin_card.year_trend_badge_class}"}
                aria-label={"Há 1 ano: #{@basin_card.year_change_label}"}
              >
                Há 1 ano: {@basin_card.year_change_label}
              </span>
            </div>
          </div>

          <div class="pt-2">
            <div class="inline-flex rounded-full bg-slate-100 p-1 text-xs font-medium text-slate-600">
              <button
                type="button"
                class="rounded-full px-3 py-1 bg-white text-slate-700 shadow-sm"
                data-basin-tab="table"
                onclick="selectBasinTab('table')"
              >
                Barragens
              </button>
              <button
                type="button"
                class="rounded-full px-3 py-1"
                data-basin-tab="chart"
                onclick="selectBasinTab('chart')"
              >
                Evolução
              </button>
            </div>
          </div>

          <div :if={@basin_card.dams != []} id="basinTabTable" class="pt-2 flex flex-col">
            <p class="text-xs uppercase tracking-[0.2em] text-slate-500">Barragens</p>
            <div class="mt-2 h-[42vh] overflow-y-auto rounded-xl border border-slate-200">
              <table class="w-full text-sm">
                <thead class="bg-slate-50 text-slate-500">
                  <tr>
                    <th class="px-2 py-1.5 text-left font-medium">Nome</th>
                    <th class="px-2 py-1.5 text-right font-medium">Atual</th>
                    <th class="px-2 py-1.5 text-right font-medium">Histórico</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-100">
                  <%= for dam <- @basin_card.dams do %>
                    <tr class="hover:bg-slate-50">
                      <td class="align-top px-2 py-1.5">
                        <a
                          href={~p"/basins/#{@basin_id}/dams/#{dam.id}"}
                          data-phx-link="patch"
                          data-phx-link-state="push"
                          class="text-brand-600 hover:text-brand-700"
                        >
                          {dam.name}
                        </a>
                      </td>
                      <td class="align-top px-2 py-1.5 text-right">
                        <span
                          id={"basin-dam-badge-#{dam.id}"}
                          class="inline-flex items-center rounded-full px-1.5 py-0.5 text-xs font-medium text-white"
                          phx-hook="CapacityColor"
                          data-observed={dam.observed}
                        >
                          {if dam.observed, do: "#{dam.observed}%", else: "n/a"}
                        </span>
                      </td>
                      <td class="align-top px-2 py-1.5 text-right">
                        <span class="inline-flex items-center rounded-full px-1.5 py-0.5 text-xs font-medium text-slate-600 bg-slate-100">
                          {if dam.average, do: "#{dam.average}%", else: "n/a"}
                        </span>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>

          <div id="basinTabChart" class="pt-2 hidden">
            <p class="text-xs uppercase tracking-[0.2em] text-slate-500">Evolução</p>
            <div class="mt-2 h-[42vh] rounded-xl border border-slate-200 bg-white p-2 flex flex-col">
              <div class="mt-auto">
                <div class="h-48">
                  <canvas
                    id="basinChart"
                    data-series={Jason.encode!(@basin_card.basin_chart_series || [])}
                  >
                  </canvas>
                </div>
                <div class="mt-2 flex items-center gap-3 text-xs text-slate-500">
                  <span class="inline-flex items-center gap-1">
                    <span class="w-2 h-2 rounded-full bg-brand-500"></span> Observado
                  </span>
                  <span class="inline-flex items-center gap-1">
                    <span class="w-2 h-2 rounded-full bg-amber-500"></span> Média
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
