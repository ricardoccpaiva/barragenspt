defmodule BarragensptWeb.Dashboard.AlertHistoryLive do
  use BarragensptWeb, :live_view

  on_mount {BarragensptWeb.UserAuth, :require_authenticated}

  alias Barragenspt.Notifications

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <.header>
            Histórico de disparos
            <:subtitle>
              {subject_emoji(@alert.subject_type)} {@alert.subject_name} — {condition_summary(@alert)}
            </:subtitle>
          </.header>
        </div>

        <%= if @events == [] do %>
          <p class="rounded-xl border border-slate-200 bg-white p-8 text-center text-sm text-slate-600 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-300">
            Este alerta ainda não disparou.
          </p>
        <% else %>
          <div class="max-w-full overflow-x-auto rounded-xl border border-slate-200 bg-white shadow-sm dark:border-slate-600 dark:bg-slate-800/40">
            <table class="min-w-full divide-y divide-slate-200 text-sm dark:divide-slate-600">
              <thead class="bg-slate-50 dark:bg-slate-800/80">
                <tr>
                  <th class="px-4 py-3 text-left font-semibold text-slate-700 dark:text-slate-200">
                    Disparo (UTC)
                  </th>
                  <th class="px-4 py-3 text-right font-semibold text-slate-700 dark:text-slate-200">
                    Valor
                  </th>
                  <th class="px-4 py-3 text-left font-semibold text-slate-700 dark:text-slate-200">Canais</th>
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
                      <div class="inline-flex flex-wrap items-center gap-1.5">
                        <%= for channel <- event_channels(event) do %>
                          <span
                            class="inline-flex rounded-lg p-1.5 text-brand-600 dark:text-brand-400"
                            title={channel_label(channel)}
                            aria-label={channel_label(channel)}
                          >
                            <.icon name={channel_icon(channel)} class="size-5" />
                          </span>
                        <% end %>
                        <%= if event_channels(event) == [] do %>
                          <span class="text-xs text-slate-500 dark:text-slate-400">—</span>
                        <% end %>
                      </div>
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
          ← Voltar aos alertas
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
         |> put_flash(:error, "Alerta não encontrado.")
         |> push_navigate(to: ~p"/dashboard/alerts")}
    end
  end

  defp subject_emoji("dam"), do: "💧"
  defp subject_emoji("basin"), do: "🏞"
  defp subject_emoji("national"), do: "🇵🇹"
  defp subject_emoji(_), do: "•"

  defp condition_summary(a) do
    m = condition_metric_label(a.metric)
    op = if a.operator == "lt", do: "inferior a", else: "superior a"
    "#{m} #{op} #{threshold_with_unit(a.metric, a.threshold)}"
  end

  defp metric_label("storage_pct"), do: "Ocupação %"
  defp metric_label("month_change_pct"), do: "Var. 1 mês (pp)"
  defp metric_label("year_change_pct"), do: "Var. 1 ano (pp)"
  defp metric_label("realtime_level"), do: "Cota (m, realtime)"
  defp metric_label("realtime_inflow"), do: "Caudal afluente (m3/s, realtime)"
  defp metric_label("realtime_outflow"), do: "Caudal efluente (m3/s, realtime)"
  defp metric_label("realtime_storage"), do: "Volume armazenado (%, realtime)"
  defp metric_label("daily_discharged_flow"), do: "Caudal descarregado médio diário (m3/s)"
  defp metric_label("daily_tributary_flow"), do: "Caudal afluente médio diário (m3/s)"
  defp metric_label("daily_effluent_flow"), do: "Caudal efluente médio diário (m3/s)"
  defp metric_label("daily_turbocharged_flow"), do: "Caudal turbinado médio diário (m3/s)"
  defp metric_label(_), do: "?"

  defp condition_metric_label("storage_pct"), do: "Ocupação"
  defp condition_metric_label("month_change_pct"), do: "Var. 1 mês"
  defp condition_metric_label("year_change_pct"), do: "Var. 1 ano"
  defp condition_metric_label("realtime_level"), do: "Cota (realtime)"
  defp condition_metric_label("realtime_inflow"), do: "Caudal afluente (realtime)"
  defp condition_metric_label("realtime_outflow"), do: "Caudal efluente (realtime)"
  defp condition_metric_label("realtime_storage"), do: "Volume armazenado (realtime)"
  defp condition_metric_label("daily_discharged_flow"), do: "Caudal descarregado médio diário"
  defp condition_metric_label("daily_tributary_flow"), do: "Caudal afluente médio diário"
  defp condition_metric_label("daily_effluent_flow"), do: "Caudal efluente médio diário"
  defp condition_metric_label("daily_turbocharged_flow"), do: "Caudal turbinado médio diário"
  defp condition_metric_label(metric), do: metric_label(metric)

  defp threshold_with_unit(metric, threshold)
       when metric in [
              "realtime_inflow",
              "realtime_outflow",
              "daily_discharged_flow",
              "daily_tributary_flow",
              "daily_effluent_flow",
              "daily_turbocharged_flow"
            ],
    do: "#{threshold} m3/s"

  defp threshold_with_unit("realtime_level", threshold), do: "#{threshold} m"
  defp threshold_with_unit("storage_pct", threshold), do: "#{threshold}%"
  defp threshold_with_unit("month_change_pct", threshold), do: "#{threshold} pp"
  defp threshold_with_unit("year_change_pct", threshold), do: "#{threshold} pp"
  defp threshold_with_unit("realtime_storage", threshold), do: "#{threshold}%"
  defp threshold_with_unit(_, threshold), do: to_string(threshold)

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

  defp format_metric_value("realtime_level", v) when is_float(v), do: "#{Float.round(v, 2)} m"
  defp format_metric_value("realtime_inflow", v) when is_float(v), do: "#{Float.round(v, 2)} m3/s"
  defp format_metric_value("realtime_outflow", v) when is_float(v), do: "#{Float.round(v, 2)} m3/s"
  defp format_metric_value("realtime_storage", v) when is_float(v), do: "#{Float.round(v, 2)}%"
  defp format_metric_value("daily_discharged_flow", v) when is_float(v), do: "#{Float.round(v, 2)} m3/s"
  defp format_metric_value("daily_tributary_flow", v) when is_float(v), do: "#{Float.round(v, 2)} m3/s"
  defp format_metric_value("daily_effluent_flow", v) when is_float(v), do: "#{Float.round(v, 2)} m3/s"
  defp format_metric_value("daily_turbocharged_flow", v) when is_float(v), do: "#{Float.round(v, 2)} m3/s"

  defp format_metric_value(_metric, v) when is_float(v) do
    "#{Float.round(v, 2)}"
  end

  defp format_metric_value(_metric, v) when is_integer(v), do: Integer.to_string(v)
  defp format_metric_value(_metric, nil), do: "—"
  defp format_metric_value(_metric, v), do: inspect(v)

  defp event_channels(%{notification_channels: channels}) when is_list(channels), do: channels
  defp event_channels(%{notified: true}), do: []
  defp event_channels(_), do: []

  defp channel_label("email"), do: "E-mail"
  defp channel_label("telegram"), do: "Telegram"
  defp channel_label(other) when is_binary(other), do: other
  defp channel_label(_), do: "Canal"

  defp channel_icon("email"), do: "hero-envelope"
  defp channel_icon("telegram"), do: "hero-paper-airplane"
  defp channel_icon(_), do: "hero-bell"
end
