defmodule BarragensptWeb.Dashboard.AdminLive do
  use BarragensptWeb, :live_view

  alias Barragenspt.Admin

  @refresh_ms 30_000
  @windows ["24h", "7d", "30d"]
  @tabs ["api", "notifications"]
  @users_per_page 10

  on_mount {BarragensptWeb.UserAuth, :require_admin}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :refresh, @refresh_ms)

    {:ok,
     socket
     |> assign(:windows, @windows)
     |> assign(:tabs, @tabs)
     |> assign(:window, "24h")
     |> assign(:tab, "api")
     |> assign(:totals, %{requests: 0, active_api_tokens: 0, users_with_usage: 0, spike_buckets: 0})
      |> assign(:usage_chart, %{labels: [], datasets: []})
      |> assign(:top_users, [])
      |> assign(:top_tokens, [])
     |> assign(:notifications_totals, %{active_alerts: 0, triggered_events: 0, notified_events: 0, users_with_alert_events: 0})
     |> assign(:notifications_chart, %{labels: [], datasets: []})
     |> assign(:top_notification_users, [])
     |> assign(:top_notifications, [])
     |> assign(:users_page, 1)
     |> assign(:registered_users, %{entries: [], page: 1, per_page: @users_per_page, total_entries: 0, total_pages: 1})
     |> load_data()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    window = normalize_window(params["window"])
    tab = normalize_tab(params["tab"])
    users_page = normalize_users_page(params["users_page"])
    {:noreply, socket |> assign(:window, window) |> assign(:tab, tab) |> assign(:users_page, users_page) |> load_data()}
  end

  @impl true
  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, @refresh_ms)
    {:noreply, load_data(socket)}
  end

  @impl true
  def handle_event("set_window", %{"window" => window}, socket) do
    {:noreply,
     push_patch(
       socket,
       to: ~p"/dashboard/admin?#{%{window: normalize_window(window), tab: socket.assigns.tab, users_page: socket.assigns.users_page}}"
     )}
  end

  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply,
     push_patch(
       socket,
       to: ~p"/dashboard/admin?#{%{window: socket.assigns.window, tab: normalize_tab(tab), users_page: socket.assigns.users_page}}"
     )}
  end

  def handle_event("set_users_page", %{"page" => page}, socket) do
    {:noreply,
     push_patch(
       socket,
       to:
         ~p"/dashboard/admin?#{%{window: socket.assigns.window, tab: socket.assigns.tab, users_page: normalize_users_page(page)}}"
     )}
  end

  defp load_data(socket) do
    window = socket.assigns.window
    usage_chart = Admin.api_usage_stacked_chart(window, 8)
    notifications_chart = Admin.notifications_stacked_chart(window, 8)

    socket
    |> assign(:totals, Admin.api_totals(window))
    |> assign(:usage_chart, usage_chart)
    |> assign(:top_users, Admin.api_usage_by_user(window, 8))
    |> assign(:top_tokens, Admin.api_usage_by_token(window, 8))
    |> assign(:notifications_totals, Admin.notifications_totals(window))
    |> assign(:notifications_chart, notifications_chart)
    |> assign(:top_notification_users, Admin.notifications_by_user(window, 8))
    |> assign(:top_notifications, Admin.notifications_by_notification(window, 8))
    |> assign(:registered_users, Admin.list_registered_users(socket.assigns.users_page, @users_per_page))
    |> maybe_push_main_chart()
  end

  attr :title, :string, required: true
  attr :value, :string, required: true

  defp kpi(assigns) do
    ~H"""
    <article class="rounded-xl border border-slate-200 bg-white p-3 dark:border-slate-600 dark:bg-slate-800/50">
      <p class="text-xs uppercase tracking-wide text-slate-500 dark:text-slate-400">{@title}</p>
      <p class="mt-1 text-2xl font-semibold text-slate-900 dark:text-slate-100">{@value}</p>
    </article>
    """
  end

  defp normalize_window(window) when window in @windows, do: window
  defp normalize_window(_), do: "24h"

  defp normalize_tab(tab) when tab in @tabs, do: tab
  defp normalize_tab(_), do: "api"

  defp normalize_users_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {value, ""} when value > 0 -> value
      _ -> 1
    end
  end

  defp normalize_users_page(page) when is_integer(page) and page > 0, do: page
  defp normalize_users_page(_), do: 1

  defp maybe_push_main_chart(socket) do
    chart = if socket.assigns.tab == "notifications", do: socket.assigns.notifications_chart, else: socket.assigns.usage_chart

    if connected?(socket) do
      push_event(socket, "admin-product-chart", chart)
    else
      socket
    end
  end

  defp fmt_int(nil), do: "0"
  defp fmt_int(v) when is_integer(v), do: v |> Integer.to_string() |> add_sep()
  defp fmt_int(v), do: to_string(v)

  defp add_sep(str) do
    str
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map_join(".", &Enum.join/1)
    |> String.reverse()
  end

  defp top_pct(_value, [], _field), do: 0

  defp top_pct(value, rows, field) do
    max_total = rows |> Enum.map(&Map.get(&1, field, 0)) |> Enum.max(fn -> 1 end)
    Float.round(value / max_total * 100, 1)
  end
end
