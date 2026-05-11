defmodule BarragensptWeb.StorageReportComponents do
  @moduledoc false
  use BarragensptWeb, :component

  embed_templates "storage_report_components/*"

  defp period_badge("monthly", selected_month, _selected_date),
    do: "Mês de #{Calendar.strftime(selected_month, "%Y-%m")}"

  defp period_badge(_report_type, _selected_month, selected_date),
    do: "Semana de #{Calendar.strftime(selected_date, "%Y-%m-%d")}"
end
