defmodule BarragensptWeb.DashboardLive do
  use BarragensptWeb, :live_view

  on_mount {BarragensptWeb.UserAuth, :require_authenticated}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-4">
        <.header>
          Painel
          <:subtitle>
            Área da conta autenticada.
          </:subtitle>
        </.header>
        <p class="text-sm text-slate-600 dark:text-slate-400">
          Olá, <span class="font-medium text-slate-800 dark:text-slate-200">
            {@current_scope.user.email}
          </span>. Esta secção está preparada para futuras funcionalidades (favoritos, alertas, etc.).
        </p>
        <div class="flex flex-wrap gap-4">
          <.link
            navigate={~p"/dashboard/alerts"}
            class="inline-flex text-sm font-medium text-brand-600 hover:underline dark:text-brand-400"
          >
            Alertas
          </.link>
          <.link
            navigate={~p"/"}
            class="inline-flex text-sm font-medium text-brand-600 hover:underline dark:text-brand-400"
          >
            ← Voltar ao mapa
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
