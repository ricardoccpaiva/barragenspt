defmodule BarragensptWeb.Dashboard.AlertsLive do
  use BarragensptWeb, :live_view

  on_mount {BarragensptWeb.UserAuth, :require_authenticated}

  alias Barragenspt.Notifications

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="w-[110%] -mx-[5%] space-y-6">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <.header>
              Alerts
              <:subtitle>
                Manage conditions that email you when they are met.
              </:subtitle>
            </.header>
            <.link
              navigate={~p"/dashboard/alerts/new"}
              class="inline-flex rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white hover:bg-brand-700"
            >
              Create alert
            </.link>
          </div>

          <%= if @rows == [] do %>
            <p class="rounded-xl border border-slate-200 bg-white p-8 text-center text-sm text-slate-600 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-300">
              You don’t have any alerts yet.
              <.link navigate={~p"/dashboard/alerts/new"} class="font-semibold text-brand-600 dark:text-brand-400">
                Create the first one
              </.link>
            </p>
          <% else %>
            <div class="overflow-x-auto rounded-xl border border-slate-200 dark:border-slate-600">
              <table class="min-w-full divide-y divide-slate-200 text-sm dark:divide-slate-600">
                <thead class="bg-slate-50 dark:bg-slate-800/80">
                  <tr>
                    <th class="px-4 py-3 text-left font-semibold text-slate-700 dark:text-slate-200">
                      Subject
                    </th>
                    <th class="px-4 py-3 text-left font-semibold text-slate-700 dark:text-slate-200">
                      Condition
                    </th>
                    <th class="px-4 py-3 text-left font-semibold text-slate-700 dark:text-slate-200">
                      Status
                    </th>
                    <th class="px-4 py-3 text-right font-semibold text-slate-700 dark:text-slate-200">
                      Triggered
                    </th>
                    <th class="px-4 py-3 text-left font-semibold text-slate-700 dark:text-slate-200">
                      Last fired
                    </th>
                    <th class="px-4 py-3 text-right font-semibold text-slate-700 dark:text-slate-200">
                      Actions
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-200 bg-white dark:divide-slate-600 dark:bg-slate-800/40">
                  <%= for row <- @rows do %>
                    <tr class={if !row.alert.active, do: "opacity-60", else: ""}>
                      <td class="px-4 py-3">
                        <span class="font-medium text-slate-900 dark:text-slate-100">
                          {subject_emoji(row.alert.subject_type)} {row.alert.subject_name}
                        </span>
                      </td>
                      <td class="px-4 py-3 text-slate-700 dark:text-slate-300">
                        {condition_row(row.alert)}
                      </td>
                      <td class="px-4 py-3">
                        <.status_badge row={row} />
                      </td>
                      <td class="px-4 py-3 text-right tabular-nums text-slate-700 dark:text-slate-300">
                        {row.triggered_count}×
                      </td>
                      <td class="px-4 py-3 text-slate-600 dark:text-slate-400">
                        {format_last(row.triggered_at)}
                      </td>
                      <td class="px-4 py-3 text-right">
                        <div class="inline-flex items-center justify-end gap-0.5">
                          <.link
                            navigate={~p"/dashboard/alerts/#{row.alert.id}/edit"}
                            class="inline-flex rounded-lg p-1.5 text-brand-600 hover:bg-brand-50 focus:outline-none focus:ring-2 focus:ring-brand-500 dark:text-brand-400 dark:hover:bg-brand-900/30"
                            aria-label="Edit alert"
                            title="Edit"
                          >
                            <.icon name="hero-pencil-square" class="size-5" />
                          </.link>
                          <button
                            type="button"
                            phx-click="toggle"
                            phx-value-id={row.alert.id}
                            class="inline-flex rounded-lg p-1.5 text-brand-600 hover:bg-brand-50 focus:outline-none focus:ring-2 focus:ring-brand-500 dark:text-brand-400 dark:hover:bg-brand-900/30"
                            aria-label={if row.alert.active, do: "Pause alert", else: "Resume alert"}
                            title={if row.alert.active, do: "Pause", else: "Resume"}
                          >
                            <%= if row.alert.active do %>
                              <.icon name="hero-pause" class="size-5" />
                            <% else %>
                              <.icon name="hero-play" class="size-5" />
                            <% end %>
                          </button>
                          <button
                            type="button"
                            phx-click="delete"
                            phx-value-id={row.alert.id}
                            data-confirm="Remove this alert?"
                            class="inline-flex rounded-lg p-1.5 text-red-600 hover:bg-red-50 focus:outline-none focus:ring-2 focus:ring-red-500 dark:text-red-400 dark:hover:bg-red-900/25"
                            aria-label="Delete alert"
                            title="Delete"
                          >
                            <.icon name="hero-trash" class="size-5" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>

        <.link
          navigate={~p"/dashboard"}
          class="inline-flex text-sm font-medium text-brand-600 hover:underline dark:text-brand-400"
        >
          ← Dashboard
        </.link>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("toggle", %{"id" => id}, socket) do
    user_id = socket.assigns.current_scope.user.id

    case Notifications.toggle_active(id, user_id) do
      {:ok, _} ->
        {:noreply, assign(socket, rows: load_rows(user_id))}

      _ ->
        {:noreply, put_flash(socket, :error, "Could not update alert.")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user_id = socket.assigns.current_scope.user.id

    case Notifications.delete_alert(id, user_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Alert removed.")
         |> assign(rows: load_rows(user_id))}

      _ ->
        {:noreply, put_flash(socket, :error, "Could not remove alert.")}
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    rows = load_rows(user_id)
    {:ok, assign(socket, rows: rows)}
  end

  defp load_rows(user_id) do
    Notifications.list_alerts_with_stats(user_id)
    |> Enum.map(fn %{alert: a, triggered_count: c, last_triggered_at: t} ->
      {met?, val} = if a.active, do: Notifications.compute_status(a), else: {false, nil}
      %{alert: a, triggered_count: c, triggered_at: t, met?: met?, current_value: val}
    end)
  end

  defp subject_emoji("dam"), do: "💧"
  defp subject_emoji("basin"), do: "🏞"
  defp subject_emoji("national"), do: "🇵🇹"
  defp subject_emoji(_), do: "•"

  defp condition_row(a) do
    m = metric_label(a.metric)
    op = if a.operator == "lt", do: "below", else: "above"
    "#{m} #{op} #{a.threshold}"
  end

  defp metric_label("storage_pct"), do: "Storage %"
  defp metric_label("month_change_pct"), do: "Δ 1 month (pp)"
  defp metric_label("year_change_pct"), do: "Δ 1 year (pp)"
  defp metric_label(_), do: "?"

  attr :row, :map, required: true

  def status_badge(assigns) do
    kind =
      cond do
        !assigns.row.alert.active -> :paused
        assigns.row.met? -> :active
        true -> :ok
      end

    assigns = assign(assigns, :kind, kind)

    ~H"""
    <%= case @kind do %>
      <% :paused -> %>
        <span class="inline-flex rounded-full bg-slate-200 px-2 py-0.5 text-xs font-medium text-slate-800 dark:bg-slate-600 dark:text-slate-100">
          Paused
        </span>
      <% :active -> %>
        <span class="inline-flex rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800 dark:bg-green-900/40 dark:text-green-200">
          Active
        </span>
      <% :ok -> %>
        <span class="inline-flex rounded-full bg-emerald-100 px-2 py-0.5 text-xs font-medium text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-200">
          OK
        </span>
    <% end %>
    """
  end

  defp format_last(nil), do: "Never"

  defp format_last(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
  end

  defp format_last(%NaiveDateTime{} = ndt) do
    NaiveDateTime.to_string(ndt)
  end
end
