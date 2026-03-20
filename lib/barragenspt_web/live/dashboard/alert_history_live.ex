defmodule BarragensptWeb.Dashboard.AlertHistoryLive do
  use BarragensptWeb, :live_view

  on_mount {BarragensptWeb.UserAuth, :require_authenticated}

  alias Barragenspt.Notifications

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="w-[110%] -mx-[5%] space-y-6">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <.header>
            Trigger history
            <:subtitle>
              {subject_emoji(@alert.subject_type)} {@alert.subject_name} — {condition_summary(@alert)}
            </:subtitle>
          </.header>
        </div>

        <%= if @events == [] do %>
          <p class="rounded-xl border border-slate-200 bg-white p-8 text-center text-sm text-slate-600 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-300">
            This alert has not fired yet.
          </p>
        <% else %>
          <div class="overflow-x-auto rounded-xl border border-slate-200 dark:border-slate-600">
            <table class="min-w-full divide-y divide-slate-200 text-sm dark:divide-slate-600">
              <thead class="bg-slate-50 dark:bg-slate-800/80">
                <tr>
                  <th class="px-4 py-3 text-left font-semibold text-slate-700 dark:text-slate-200">
                    Triggered at (UTC)
                  </th>
                  <th class="px-4 py-3 text-right font-semibold text-slate-700 dark:text-slate-200">
                    Value
                  </th>
                  <th class="px-4 py-3 text-left font-semibold text-slate-700 dark:text-slate-200">
                    Emailed
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-200 bg-white dark:divide-slate-600 dark:bg-slate-800/40">
                <%= for event <- @events do %>
                  <tr>
                    <td class="px-4 py-3 tabular-nums text-slate-700 dark:text-slate-300">
                      {format_triggered_at(event.triggered_at)}
                    </td>
                    <td class="px-4 py-3 text-right tabular-nums text-slate-700 dark:text-slate-300">
                      {format_metric_value(@alert.metric, event.value_at_trigger)}
                    </td>
                    <td class="px-4 py-3 text-slate-700 dark:text-slate-300">
                      {if event.notified, do: "Yes", else: "No"}
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>

        <.link
          navigate={~p"/dashboard/alerts"}
          class="inline-flex text-sm font-medium text-brand-600 hover:underline dark:text-brand-400"
        >
          ← Back to alerts
        </.link>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user_id = socket.assigns.current_scope.user.id

    case Notifications.fetch_alert_with_events(id, user_id) do
      {:ok, alert, events} ->
        {:ok, assign(socket, alert: alert, events: events)}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Alert not found.")
         |> push_navigate(to: ~p"/dashboard/alerts")}
    end
  end

  defp subject_emoji("dam"), do: "💧"
  defp subject_emoji("basin"), do: "🏞"
  defp subject_emoji("national"), do: "🇵🇹"
  defp subject_emoji(_), do: "•"

  defp condition_summary(a) do
    m = metric_label(a.metric)
    op = if a.operator == "lt", do: "below", else: "above"
    "#{m} #{op} #{a.threshold}"
  end

  defp metric_label("storage_pct"), do: "Storage %"
  defp metric_label("month_change_pct"), do: "Δ 1 month (pp)"
  defp metric_label("year_change_pct"), do: "Δ 1 year (pp)"
  defp metric_label(_), do: "?"

  defp format_triggered_at(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_triggered_at(%NaiveDateTime{} = ndt) do
    NaiveDateTime.to_string(ndt)
  end

  defp format_triggered_at(_), do: "—"

  defp format_metric_value("storage_pct", v) when is_float(v) do
    "#{Float.round(v, 2)}%"
  end

  defp format_metric_value(metric, v)
       when is_float(v) and metric in ["month_change_pct", "year_change_pct"] do
    "#{Float.round(v, 2)} pp"
  end

  defp format_metric_value(_metric, v) when is_float(v) do
    "#{Float.round(v, 2)}"
  end

  defp format_metric_value(_metric, v) when is_integer(v), do: Integer.to_string(v)
  defp format_metric_value(_metric, nil), do: "—"
  defp format_metric_value(_metric, v), do: inspect(v)
end
