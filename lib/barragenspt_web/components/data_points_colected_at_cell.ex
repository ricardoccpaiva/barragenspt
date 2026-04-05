defmodule BarragensptWeb.DataPointsColectedAtCell do
  @moduledoc false
  use Phoenix.Component

  attr :at, :any, default: nil

  def data_points_colected_at_cell(assigns) do
    ~H"""
    <%= if @at do %>
      <div class="inline-flex min-w-0 flex-col items-start gap-0.5 tabular-nums leading-tight">
        <span class="text-sm text-slate-900 dark:text-slate-100">
          {Calendar.strftime(@at, "%d/%m/%Y")}
        </span>
        <span class="self-end text-xs leading-none text-slate-500 dark:text-slate-400">
          {Calendar.strftime(@at, "%H:%M:%S")}
        </span>
      </div>
    <% else %>
      —
    <% end %>
    """
  end
end
