defmodule BarragensptWeb.HomepageV2Live.BasinCardComponent do
  use BarragensptWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <section id="basinInfoPanel" class="fixed bottom-2 right-2 z-40 w-[360px]">
      <div class="bg-slate-100/65 dark:bg-slate-800/70 backdrop-blur-md rounded-2xl shadow-float border border-slate-200/50 dark:border-slate-600/60 overflow-hidden text-[13px] text-slate-800 dark:text-slate-200">
        <div class="h-10 px-3 rounded-t-2xl flex items-center justify-between bg-slate-800 border-b border-slate-800 text-white">
          <div>
            <p class="text-sm font-semibold">
              {@basin_card.name}
            </p>
          </div>
          <a
            href="/"
            data-phx-link="patch"
            data-phx-link-state="push"
            class="text-xs text-slate-400 hover:text-white p-1 rounded"
          >
            Fechar
          </a>
        </div>
        <div class="p-3 space-y-2 text-sm text-slate-600 dark:text-slate-300">
          <div class="flex flex-col gap-1">
            <div class="flex items-start gap-2">
              <p class="text-2xl font-bold text-slate-900 dark:text-slate-100 tabular-nums">
                {if @basin_card.avg_observed, do: "#{@basin_card.avg_observed}%", else: "n/a"}
              </p>
              <span class="text-[10px] uppercase tracking-[0.15em] text-slate-500 dark:text-slate-400">Atual</span>
            </div>
            <p class="text-xs text-slate-500 dark:text-slate-400">
              Volume armazenado:
              <span class="font-medium text-slate-700 dark:text-slate-300 tabular-nums">
                {@basin_card.total_storage_label}
              </span>
            </p>
            <div
              class="h-1.5 rounded-full bg-slate-200 dark:bg-slate-600 overflow-hidden"
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
            <div class="flex flex-wrap gap-1">
              <span
                class={"inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium #{@basin_card.month_trend_badge_class}"}
                aria-label={"Há 1 mês: #{@basin_card.month_change_label}"}
              >
                Há 1 mês: {@basin_card.month_change_label}
              </span>
              <span
                class={"inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium #{@basin_card.year_trend_badge_class}"}
                aria-label={"Há 1 ano: #{@basin_card.year_change_label}"}
              >
                Há 1 ano: {@basin_card.year_change_label}
              </span>
            </div>
          </div>

          <div class="pt-1">
            <div class="inline-flex rounded-full bg-slate-200/80 dark:bg-slate-600 p-0.5 text-xs font-medium text-slate-600 dark:text-slate-300">
              <button
                type="button"
                class="rounded-full px-2.5 py-0.5 bg-slate-50 dark:bg-slate-700 text-slate-700 dark:text-slate-200 shadow-sm"
                data-basin-tab="table"
                onclick="selectBasinTab('table')"
              >
                Barragens
              </button>
              <button
                type="button"
                class="rounded-full px-2.5 py-0.5 text-slate-600 dark:text-slate-300"
                data-basin-tab="chart"
                onclick="selectBasinTab('chart')"
              >
                Evolução
              </button>
            </div>
          </div>

          <div :if={@basin_card.dams != []} id="basinTabTable" class="pt-1.5 flex flex-col">
            <p class="text-xs uppercase tracking-[0.2em] text-slate-500 dark:text-slate-400">Barragens</p>
            <div class="mt-1.5 h-[32vh] overflow-y-auto rounded-lg border border-slate-200/80 dark:border-slate-600 bg-slate-100/60 dark:bg-slate-700/60">
              <table class="w-full text-sm">
                <thead class="bg-slate-200/60 dark:bg-slate-600/80 text-slate-500 dark:text-slate-300">
                  <tr>
                    <th class="px-2 py-1 text-left font-medium">Nome</th>
                    <th class="px-2 py-1 text-right font-medium">Atual</th>
                    <th class="px-2 py-1 text-right font-medium">Histórico</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-200/80 dark:divide-slate-600">
                  <%= for dam <- @basin_card.dams do %>
                    <tr class="hover:bg-slate-100/80 dark:hover:bg-slate-600/50">
                      <td class="align-top px-2 py-1">
                        <a
                          href={~p"/basins/#{@basin_id}/dams/#{dam.id}"}
                          data-phx-link="patch"
                          data-phx-link-state="push"
                          class="text-brand-600 hover:text-brand-700 dark:text-brand-400 dark:hover:text-brand-300"
                        >
                          {dam.name}
                        </a>
                      </td>
                      <td class="align-top px-2 py-1 text-right">
                        <span
                          id={"basin-dam-badge-#{dam.id}"}
                          class="inline-flex items-center rounded-full px-1.5 py-0.5 text-xs font-medium text-white dark:ring-1 dark:ring-white/20"
                          phx-hook="CapacityColor"
                          data-observed={dam.observed}
                        >
                          {if dam.observed, do: "#{dam.observed}%", else: "n/a"}
                        </span>
                      </td>
                      <td class="align-top px-2 py-1 text-right">
                        <span class="inline-flex items-center rounded-full px-1.5 py-0.5 text-xs font-medium text-slate-600 bg-slate-100 dark:text-slate-200 dark:bg-slate-600">
                          {if dam.average, do: "#{dam.average}%", else: "n/a"}
                        </span>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>

          <div id="basinTabChart" class="pt-1.5 hidden">
            <p class="text-xs uppercase tracking-[0.2em] text-slate-500 dark:text-slate-400">Evolução</p>
            <div class="mt-1.5 h-[32vh] rounded-lg border border-slate-200/80 dark:border-slate-600 bg-slate-100/60 dark:bg-slate-700/60 p-2 flex flex-col">
              <div class="mt-auto">
                <div class="h-36">
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
