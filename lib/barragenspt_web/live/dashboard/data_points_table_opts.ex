defmodule BarragensptWeb.DataPointsTableOpts do
  @moduledoc false

  alias BarragensptWeb.DataPointsTableEmptyHtml

  @table_opts_base [
    container: true,
    container_attrs: [
      class:
        "overflow-x-auto rounded-2xl border border-slate-200/90 bg-white shadow-[0_4px_24px_-6px_rgba(15,23,42,0.12)] ring-1 ring-slate-950/[0.04] dark:border-slate-700/90 dark:bg-slate-900/45 dark:shadow-[0_8px_32px_-8px_rgba(0,0,0,0.55)] dark:ring-white/[0.06]"
    ],
    table_attrs: [
      class: "min-w-full border-collapse text-sm"
    ],
    thead_attrs: [
      class:
        "sticky top-0 z-10 border-b border-slate-200/90 bg-slate-50/90 backdrop-blur-md dark:border-slate-700/80 dark:bg-slate-950/85"
    ],
    thead_th_attrs: [
      class:
        "px-4 py-3 text-left text-sm font-bold uppercase tracking-[0.07em] text-slate-500 first:pl-5 last:pr-5 dark:text-slate-400"
    ],
    tbody_attrs: [
      class:
        "[&>tr:nth-child(even)]:bg-slate-50/70 [&>tr:hover]:bg-sky-50/60 dark:[&>tr:nth-child(even)]:bg-slate-800/25 dark:[&>tr:hover]:bg-slate-800/55"
    ],
    tbody_td_attrs: [
      class:
        "px-4 py-3 align-middle text-slate-700 first:pl-5 last:pr-5 dark:text-slate-300"
    ],
    tbody_tr_attrs: [
      class:
        "border-b border-slate-100/90 transition-colors duration-200 last:border-b-0 dark:border-slate-800/70"
    ]
  ]

  @spec table_opts_flex_fill(boolean()) :: keyword()
  def table_opts_flex_fill(awaiting_param?) when is_boolean(awaiting_param?) do
    opts = table_opts(awaiting_param?)

    Keyword.update(opts, :container_attrs, [], fn attrs ->
      Keyword.update(attrs, :class, "", fn c -> "#{c} flex min-h-0 flex-1 flex-col overflow-auto" end)
    end)
  end

  defp table_opts(awaiting_param?) when is_boolean(awaiting_param?) do
    no_results =
      if awaiting_param? do
        DataPointsTableEmptyHtml.awaiting_param()
      else
        DataPointsTableEmptyHtml.empty_filters()
      end

    Keyword.put(@table_opts_base, :no_results_content, no_results)
  end

  @spec flop_pagination_page_link_attrs :: keyword()
  def flop_pagination_page_link_attrs do
    [
      class:
        "inline-flex min-h-8 min-w-8 shrink-0 items-center justify-center rounded-full border border-slate-200/90 bg-white px-2 text-xs font-medium tabular-nums text-slate-600 shadow-sm transition-colors hover:border-slate-300 hover:bg-slate-50 hover:text-slate-900 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-300 dark:hover:border-slate-500 dark:hover:bg-slate-700 dark:hover:text-slate-100"
    ]
  end

  @spec flop_pagination_current_attrs :: keyword()
  def flop_pagination_current_attrs do
    [
      class:
        "inline-flex min-h-8 min-w-8 shrink-0 cursor-default items-center justify-center rounded-full border border-brand-600 bg-brand-600 px-2 text-xs font-semibold tabular-nums text-white shadow-sm dark:border-brand-500 dark:bg-brand-600 dark:text-white"
    ]
  end

  @spec flop_pagination_prev_attrs :: keyword()
  def flop_pagination_prev_attrs do
    [
      class:
        "order-1 inline-flex min-h-8 shrink-0 items-center justify-center rounded-full border border-slate-200/90 bg-white px-3 text-xs font-medium text-slate-600 shadow-sm transition-colors hover:border-slate-300 hover:bg-slate-50 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-300 dark:hover:bg-slate-700"
    ]
  end

  @spec flop_pagination_next_attrs :: keyword()
  def flop_pagination_next_attrs do
    [
      class:
        "order-3 inline-flex min-h-8 shrink-0 items-center justify-center rounded-full border border-slate-200/90 bg-white px-3 text-xs font-medium text-slate-600 shadow-sm transition-colors hover:border-slate-300 hover:bg-slate-50 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-300 dark:hover:bg-slate-700"
    ]
  end

  @spec flop_pagination_disabled_attrs :: keyword()
  def flop_pagination_disabled_attrs do
    [
      class:
        "inline-flex min-h-8 shrink-0 cursor-not-allowed items-center justify-center rounded-full border border-transparent px-3 text-xs text-slate-400 dark:text-slate-500"
    ]
  end
end
