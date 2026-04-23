defmodule BarragensptWeb.WorkerStatusLive do
  use BarragensptWeb, :live_view

  alias Barragenspt.WorkerStatus

  @refresh_ms 30_000
  @display_tz "Europe/Lisbon"

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :refresh, @refresh_ms)
    end

    {:ok,
     socket
     |> assign(:summaries, WorkerStatus.list_worker_summaries())
     |> assign(:show_runs_modal, false)
     |> assign(:modal_worker_name, nil)
     |> assign(:modal_runs, [])
     |> assign(:modal_summary, empty_modal_summary())}
  end

  @impl true
  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, @refresh_ms)
    {:noreply, assign(socket, :summaries, WorkerStatus.list_worker_summaries())}
  end

  @impl true
  def handle_event("open_runs_modal", %{"worker" => worker}, socket) do
    worker_module =
      WorkerStatus.tracked_workers()
      |> Enum.find(fn mod -> to_string(mod) == worker end)

    if worker_module do
      runs = WorkerStatus.last_runs(worker_module, 30)
      summary = WorkerStatus.summarize_runs(runs)

      {:noreply,
       socket
       |> assign(:show_runs_modal, true)
       |> assign(:modal_worker_name, worker_module |> Module.split() |> List.last())
       |> assign(:modal_runs, runs)
       |> assign(:modal_summary, summary)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_runs_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_runs_modal, false)
     |> assign(:modal_worker_name, nil)
     |> assign(:modal_runs, [])
     |> assign(:modal_summary, empty_modal_summary())}
  end

  def handle_event("noop", _params, socket) do
    {:noreply, socket}
  end

  defp format_datetime(nil), do: "n/a"

  defp format_datetime(%DateTime{} = dt) do
    case DateTime.shift_zone(dt, @display_tz) do
      {:ok, shifted} -> Calendar.strftime(shifted, "%d/%m/%Y %H:%M:%S")
      _ -> Calendar.strftime(dt, "%d/%m/%Y %H:%M:%S")
    end
  end

  defp format_countdown(nil), do: "n/a"
  defp format_countdown(seconds) when seconds < 60, do: "#{seconds}s"

  defp format_countdown(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    secs = rem(seconds, 60)

    cond do
      hours > 0 -> "#{hours}h #{minutes}m #{secs}s"
      true -> "#{minutes}m #{secs}s"
    end
  end

  defp format_duration(nil), do: "n/a"
  defp format_duration(ms) when ms < 1000, do: "#{ms} ms"
  defp format_duration(ms), do: "#{Float.round(ms / 1000, 2)} s"

  defp status_badge_class("running"),
    do:
      "inline-flex rounded-full bg-sky-100 px-2 py-0.5 text-xs font-medium text-sky-800 dark:bg-sky-900/40 dark:text-sky-200"

  defp status_badge_class("ok"),
    do:
      "inline-flex rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800 dark:bg-green-900/40 dark:text-green-200"

  defp status_badge_class("stale"),
    do:
      "inline-flex rounded-full bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-800 dark:bg-amber-900/40 dark:text-amber-200"

  defp status_badge_class("error"),
    do:
      "inline-flex rounded-full bg-red-100 px-2 py-0.5 text-xs font-medium text-red-800 dark:bg-red-900/40 dark:text-red-200"

  defp status_badge_class(_),
    do:
      "inline-flex rounded-full bg-slate-200 px-2 py-0.5 text-xs font-medium text-slate-800 dark:bg-slate-700 dark:text-slate-100"

  defp empty_modal_summary do
    %{
      total: 0,
      ok_count: 0,
      error_count: 0,
      running_count: 0,
      total_created: 0,
      total_updated: 0,
      avg_duration_ms: nil
    }
  end
end
