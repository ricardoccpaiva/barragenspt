defmodule BarragensptWeb.EvaluateAlertsShortcutComponent do
  @moduledoc """
  Navbar control to enqueue `Barragenspt.Workers.EvaluateAlerts`.
  """
  use BarragensptWeb, :live_component

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="enqueue"
      phx-target={@myself}
      class="inline-flex items-center rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm font-semibold text-slate-700 shadow-sm hover:bg-slate-50 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-200 dark:hover:bg-slate-700/80"
      title="Correr agora o job Oban que avalia todas as condições de alerta ativas"
    >
      Avaliar alertas
    </button>
    """
  end

  @impl true
  def handle_event("enqueue", _, socket) do
    case Barragenspt.Workers.EvaluateAlerts.schedule_manual("navbar") do
      {:ok, _job} ->
        {:noreply,
         socket
         |> Phoenix.LiveView.push_event("show_toast", %{
           message: "Avaliação de alertas agendada.",
           type: "success"
         })}

      {:error, reason} ->
        {:noreply,
         Phoenix.LiveView.push_event(socket, "show_toast", %{
           message: "Não foi possível agendar a avaliação. #{inspect(reason)}",
           type: "error"
         })}
    end
  end
end
