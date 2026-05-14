defmodule BarragensptWeb.EvaluateNotificationsShortcutComponent do
  @moduledoc """
  Navbar control to enqueue `Barragenspt.Workers.EvaluateNotifications`.
  """
  use BarragensptWeb, :live_component

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.button
        variant="primary"
        phx-click="enqueue"
        phx-target={@myself}
        type="button"
        class="px-3 py-1.5"
        title="Correr agora o job Oban que avalia todas as condições de notificação ativas"
      >
        Avaliar notificações
      </.button>
    </div>
    """
  end

  @impl true
  def handle_event("enqueue", _, socket) do
    case Barragenspt.Workers.EvaluateNotifications.schedule_manual("navbar") do
      {:ok, _job} ->
        {:noreply,
         socket
         |> Phoenix.LiveView.push_event("show_toast", %{
           message: "Avaliação de notificações agendada.",
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
