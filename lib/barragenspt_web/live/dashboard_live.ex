defmodule BarragensptWeb.DashboardLive do
  use BarragensptWeb, :live_view

  alias Barragenspt.Activity

  @impl true
  def mount(_params, _session, socket) do
    signed_in? = socket.assigns.current_scope.user != nil

    activity_summary =
      if signed_in?, do: Activity.summary_for_user(socket.assigns.current_scope.user.id)

    {:ok,
     socket
     |> assign(:signed_in?, signed_in?)
     |> assign(:activity_summary, activity_summary)}
  end

  defp user_display_name(%{display_name: name, email: email}) do
    case to_string(name || "") |> String.trim() do
      "" -> email |> to_string() |> String.split("@") |> List.first()
      value -> value
    end
  end

  defp user_display_name(_), do: "utilizador"

  defp format_count(nil), do: "0"

  defp format_count(value) when is_integer(value),
    do: value |> Integer.to_string() |> format_count_string()

  defp format_count_string(value) do
    value
    |> String.reverse()
    |> String.replace(~r/.{3}(?=.)/, "\\0 ")
    |> String.reverse()
  end

  defp notification_channel_count(summary, channel) do
    summary
    |> Map.get(:notification_channels, %{})
    |> Map.get(channel, 0)
  end

  defp notification_delivery_count(summary) do
    notification_channel_count(summary, "email") + notification_channel_count(summary, "telegram")
  end

  defp notification_trigger_count(summary, status) do
    summary
    |> Map.get(:notification_triggers, %{})
    |> Map.get(status, 0)
  end

  defp activity_stat_card(assigns) do
    ~H"""
    <div class="rounded-xl border border-slate-200 bg-white p-5 shadow-sm dark:border-slate-700 dark:bg-slate-800">
      <div class="flex items-start justify-between gap-4">
        <div class="min-w-0">
          <p class="text-xs font-semibold uppercase text-slate-500 dark:text-slate-400">{@label}</p>
          <p class="mt-2 text-3xl font-bold tracking-tight text-slate-900 dark:text-slate-50">
            {@value}
          </p>
          <p :if={@sub != nil} class="mt-1 text-sm text-slate-500 dark:text-slate-400">{@sub}</p>
        </div>
        <span class={["flex h-10 w-10 shrink-0 items-center justify-center rounded-lg", @icon_class]}>
          <.icon name={@icon} class="size-5" />
        </span>
      </div>
    </div>
    """
  end
end
