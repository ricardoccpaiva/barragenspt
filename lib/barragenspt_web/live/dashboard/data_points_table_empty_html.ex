defmodule BarragensptWeb.DataPointsTableEmptyHtml do
  @moduledoc false
  # Flop table :no_results_content expects Phoenix.HTML.safe(); kept out of LiveView module.

  @spec awaiting_param :: Phoenix.HTML.safe()
  def awaiting_param do
    Phoenix.HTML.raw(~S"""
    <div class="m-4 rounded-xl border border-dashed border-slate-200/90 bg-slate-50/80 p-10 text-center dark:border-slate-700 dark:bg-slate-800/40">
      <p class="text-sm leading-relaxed text-slate-600 dark:text-slate-300">
        Escolha um parâmetro nos filtros e clique em <span class="font-semibold text-slate-800 dark:text-slate-200">Aplicar</span> para ver dados.
      </p>
    </div>
    """)
  end

  @spec empty_filters :: Phoenix.HTML.safe()
  def empty_filters do
    Phoenix.HTML.raw(~S"""
    <div class="m-4 rounded-xl border border-dashed border-slate-200/90 bg-slate-50/80 p-10 text-center dark:border-slate-700 dark:bg-slate-800/40">
      <p class="text-sm text-slate-600 dark:text-slate-300">Sem resultados com estes filtros.</p>
    </div>
    """)
  end
end
