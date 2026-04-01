defmodule BarragensptWeb.DataPointsParamMultiselect do
  @moduledoc false
  use Phoenix.Component

  attr :options, :list, required: true, doc: "list of {label, slug} tuples"
  attr :selected, :list, default: []
  attr :open?, :boolean, default: false
  attr :panel_id, :string, default: "data-points-param-ms-panel"
  attr :search_input_id, :string, default: "data-points-param-ms-search"

  def data_points_param_multiselect(assigns) do
    n = length(assigns.selected)
    summary = param_multiselect_summary(n)

    assigns = assign(assigns, :summary, summary)

    ~H"""
    <div
      class="relative w-full min-w-0"
      phx-click-away={if(@open?, do: "param_multiselect_close")}
    >
      <button
        type="button"
        phx-click="param_multiselect_toggle"
        aria-expanded={to_string(@open?)}
        class="flex w-full items-center justify-between gap-2 rounded-md border border-slate-300 bg-white px-3 py-2 text-left text-sm text-slate-900 shadow-sm ring-brand-500 hover:border-slate-400 focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100 dark:hover:border-slate-500"
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

      <div
        id={@panel_id}
        class={[
          "absolute left-0 right-0 top-full z-50 mt-1 rounded-md border border-slate-200 bg-white py-2 shadow-lg dark:border-slate-600 dark:bg-slate-800",
          not @open? && "hidden"
        ]}
      >
        <div class="px-2 pb-2">
          <input
            id={@search_input_id}
            type="search"
            autocomplete="off"
            placeholder="Pesquisar…"
            phx-hook="DamMultiselectSearch"
            data-ms-panel={@panel_id}
            class="block w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm placeholder:text-slate-400 ring-brand-500 hover:border-slate-400 focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500 dark:border-slate-600 dark:bg-slate-900 dark:text-slate-100 dark:placeholder:text-slate-500 dark:hover:border-slate-500"
          />
        </div>
        <div class="max-h-52 overflow-y-auto border-t border-slate-100 px-1 pt-1 dark:border-slate-700">
          <%= if @options == [] do %>
            <p class="px-2 py-2 text-center text-xs text-slate-500 dark:text-slate-400">Sem parâmetros na lista.</p>
          <% else %>
            <%= for {label, slug} <- @options do %>
              <% selected? = slug in @selected %>
              <% f = String.downcase(label) %>
              <button
                type="button"
                data-ms-filter-text={f}
                phx-click="toggle_data_points_param"
                phx-value-slug={slug}
                class="flex w-full items-center gap-2 rounded px-2 py-1.5 text-left text-sm text-slate-800 hover:bg-slate-50 dark:text-slate-200 dark:hover:bg-slate-700/80"
              >
                <span class={[
                  "flex size-4 shrink-0 items-center justify-center rounded border",
                  selected? && "border-brand-600 bg-brand-600",
                  !selected? && "border-slate-300 dark:border-slate-500"
                ]}>
                  <%= if selected? do %>
                    <svg class="size-2.5 text-white" fill="none" stroke="currentColor" stroke-width="3" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
                    </svg>
                  <% end %>
                </span>
                <span class="min-w-0 flex-1 truncate">{label}</span>
              </button>
            <% end %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp param_multiselect_summary(0), do: "Escolher parâmetros…"
  defp param_multiselect_summary(1), do: "1 parâmetro selecionado"
  defp param_multiselect_summary(n) when is_integer(n), do: "#{n} parâmetros selecionados"
end
