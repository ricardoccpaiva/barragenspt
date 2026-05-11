defmodule BarragensptWeb.StorageReportComponents do
  @moduledoc false
  use BarragensptWeb, :component

  embed_templates "storage_report_components/*"

  def methodology_drawer_overlay_class(true),
    do: "fixed inset-0 z-[70] transition-opacity duration-200 opacity-100"

  def methodology_drawer_overlay_class(false),
    do: "fixed inset-0 z-[70] transition-opacity duration-200 pointer-events-none opacity-0"

  def methodology_drawer_panel_class(true),
    do:
      "flex h-full w-full max-w-[42rem] flex-col overflow-hidden border-l border-slate-200 bg-white shadow-2xl transition-transform duration-200 translate-x-0 dark:border-slate-700 dark:bg-slate-900"

  def methodology_drawer_panel_class(false),
    do:
      "flex h-full w-full max-w-[42rem] flex-col overflow-hidden border-l border-slate-200 bg-white shadow-2xl transition-transform duration-200 translate-x-full dark:border-slate-700 dark:bg-slate-900"

  def ai_drawer_overlay_class(true),
    do: "fixed inset-0 z-[70] transition-opacity duration-200 opacity-100"

  def ai_drawer_overlay_class(false),
    do: "fixed inset-0 z-[70] transition-opacity duration-200 pointer-events-none opacity-0"

  def ai_drawer_panel_class(true),
    do:
      "flex h-full w-full max-w-[42rem] flex-col overflow-hidden border-l border-slate-200 bg-white shadow-2xl transition-transform duration-200 translate-x-0 dark:border-slate-700 dark:bg-slate-900"

  def ai_drawer_panel_class(false),
    do:
      "flex h-full w-full max-w-[42rem] flex-col overflow-hidden border-l border-slate-200 bg-white shadow-2xl transition-transform duration-200 translate-x-full dark:border-slate-700 dark:bg-slate-900"

  defp period_badge("monthly", selected_month, _selected_date),
    do: "Mês de #{Calendar.strftime(selected_month, "%Y-%m")}"

  defp period_badge(_report_type, _selected_month, selected_date),
    do: "Semana de #{Calendar.strftime(selected_date, "%Y-%m-%d")}"
end
