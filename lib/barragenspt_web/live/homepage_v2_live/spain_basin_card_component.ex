defmodule BarragensptWeb.HomepageV2Live.SpainBasinCardComponent do
  @moduledoc """
  Card for Spanish basin data (Embalses.net): basin_name, current_pct, capacity_color, id.
  Expects basin_card with :name, :avg_observed (number, string like "79,29", or nil), :color (hex).
  """
  use BarragensptWeb, :live_component

  defp pct_display(assigns) do
    case assigns.basin_card.avg_observed do
      n when is_number(n) -> "#{n}%"
      s when is_binary(s) -> "#{s}%"
      _ -> "n/a"
    end
  end

  defp pct_number(assigns) do
    case assigns.basin_card.avg_observed do
      n when is_number(n) -> n
      s when is_binary(s) ->
        s
        |> String.replace(",", ".")
        |> Float.parse()
        |> case do
          {num, _} -> num
          :error -> 0
        end
      _ -> 0
    end
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:pct_number, pct_number(assigns))
      |> assign(:pct_display, pct_display(assigns))

    ~H"""
    <section id="basinInfoPanelSpain" class="fixed bottom-2 left-2 right-2 md:left-auto md:right-2 z-40 md:w-[360px]">
      <div class="bg-white/95 rounded-2xl shadow-float border border-slate-200 overflow-hidden text-[13px]">
        <div class="h-10 px-3 rounded-t-2xl flex items-center justify-between bg-slate-800 border-b border-slate-800 text-white shrink-0">
          <div>
            <p class="text-sm font-semibold">
              <%= @basin_card.name %>
            </p>
          </div>
          <div class="flex items-center gap-1">
            <button
              id="export-spain-card-btn"
              type="button"
              phx-hook="ExportBasinCard"
              data-export-target="basinInfoPanelSpain"
              data-basin-name={@basin_card.name}
              aria-label="Exportar card como imagem"
              class="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-700/80 transition-colors"
              title="Exportar card como imagem"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
              </svg>
            </button>
            <a
              href="/"
              data-phx-link="patch"
              data-phx-link-state="push"
              class="text-xs text-slate-400 hover:text-white p-1 rounded"
            >
              Fechar
            </a>
          </div>
        </div>
        <div class="p-4 space-y-3">
          <div class="flex items-baseline gap-2">
            <p class="text-3xl font-bold text-slate-900 tabular-nums">
              <%= @pct_display %>
            </p>
            <span class="text-[10px] uppercase tracking-[0.15em] text-slate-500">Espanha</span>
          </div>
          <div
            class="h-2 rounded-full bg-slate-100 overflow-hidden"
            role="progressbar"
            aria-valuenow={@pct_number}
            aria-valuemin="0"
            aria-valuemax="100"
            aria-label="Enchimento atual">
            <div
              class="h-full rounded-full transition-[width] duration-300"
              style={"width: #{@pct_number}%; background-color: #{@basin_card.color || "#94a3b8"};"}
            >
            </div>
          </div>
          <p class="text-[10px] text-slate-500">Fonte: Embalses.net</p>
        </div>
      </div>
    </section>
    """
  end
end
