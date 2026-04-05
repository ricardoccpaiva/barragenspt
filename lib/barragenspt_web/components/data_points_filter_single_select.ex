defmodule BarragensptWeb.DataPointsFilterSingleSelect do
  @moduledoc false
  use Phoenix.Component

  attr :id, :string, required: true
  attr :field, :string, required: true, doc: "Flop filter field name, e.g. param_name, basin"
  attr :options, :list, required: true, doc: "list of {label, value} tuples"
  attr :value, :string, required: true, doc: "selected option value (may be empty)"
  attr :open?, :boolean, default: false

  def data_points_filter_single_select(assigns) do
    summary =
      Enum.find_value(assigns.options, fn {label, v} ->
        if v == assigns.value, do: label
      end) ||
        assigns.options |> List.first() |> elem(0)

    assigns = assign(assigns, :summary, summary)

    ~H"""
    <div
      class="relative w-full min-w-0"
      phx-click-away={
        if(@open?, do: "data_points_single_select_close")
      }
      phx-value-field={@field}
    >
      <button
        type="button"
        phx-click="data_points_single_select_toggle"
        phx-value-field={@field}
        aria-haspopup="listbox"
        aria-expanded={to_string(@open?)}
        class="flex w-full items-center justify-between gap-1.5 rounded-md border border-slate-300 bg-white px-3 py-2 text-left text-sm text-slate-900 shadow-sm ring-brand-500 hover:border-slate-400 focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100 dark:hover:border-slate-500"
      >
        <span class="min-w-0 truncate">{@summary}</span>
        <svg
          class={["size-4 shrink-0 text-slate-500 transition-transform dark:text-slate-400", @open? && "rotate-180"]}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      <ul
        id={@id}
        role="listbox"
        class={[
          "absolute left-0 right-0 top-full z-50 mt-1 max-h-52 overflow-y-auto rounded-md border border-slate-200 bg-white py-1 shadow-lg dark:border-slate-600 dark:bg-slate-800",
          not @open? && "hidden"
        ]}
      >
        <%= for {label, opt_val} <- @options do %>
          <% selected? = opt_val == @value %>
          <li role="none">
            <button
              type="button"
              role="option"
              aria-selected={to_string(selected?)}
              phx-click="set_data_points_single_filter"
              phx-value-field={@field}
              phx-value-item={opt_val}
              class={[
                "flex w-full items-center gap-2 px-3 py-2 text-left text-sm text-slate-800 hover:bg-slate-50 dark:text-slate-200 dark:hover:bg-slate-700/80",
                selected? && "bg-brand-50 font-medium text-brand-900 dark:bg-brand-950/50 dark:text-brand-100"
              ]}
            >
              <span class="min-w-0 flex-1 truncate">{label}</span>
              <%= if selected? do %>
                <svg class="size-4 shrink-0 text-brand-600 dark:text-brand-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
              <% end %>
            </button>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end
end
