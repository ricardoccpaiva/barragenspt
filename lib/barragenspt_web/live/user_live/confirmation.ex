defmodule BarragensptWeb.UserLive.Confirmation do
  use BarragensptWeb, :live_view

  alias Barragenspt.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>
            Confirmar conta
            <:subtitle>
              {@user.email}
            </:subtitle>
          </.header>
        </div>

        <.form
          :if={!@user.confirmed_at}
          for={%{}}
          id="confirmation_form"
          phx-mounted={JS.focus_first()}
          phx-submit="submit"
        >
          <.button
            phx-disable-with="A confirmar..."
            class="w-full"
          >
            Confirmar e-mail
          </.button>
        </.form>

        <div
          :if={@user.confirmed_at}
          class="mt-6 rounded-lg border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-800 dark:border-emerald-800/60 dark:bg-emerald-950/30 dark:text-emerald-200"
        >
          Esta conta já está confirmada. Podes iniciar sessão com o teu e-mail e palavra-passe.
        </div>

        <.link
          navigate={~p"/users/log-in"}
          class="mt-4 inline-flex w-full items-center justify-center rounded-lg bg-slate-200 px-4 py-2.5 text-sm font-semibold text-slate-800 hover:bg-slate-300 dark:bg-slate-700 dark:text-slate-100 dark:hover:bg-slate-600"
        >
          Ir para iniciar sessão
        </.link>

        <p
          :if={!@user.confirmed_at}
          class="mt-8 rounded-lg border border-slate-200 bg-slate-50 p-3 text-sm text-slate-600 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-400"
        >
          Depois de confirmares o e-mail, inicia sessão normalmente com o teu e-mail e palavra-passe.
        </p>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_confirmation_token(token) do
      {:ok, assign(socket, user: user, token: token)}
    else
      {:ok,
       socket
       |> put_flash(:error, "O link de confirmação é inválido ou expirou.")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("submit", _params, socket) do
    case Accounts.confirm_user(socket.assigns.token) do
      {:ok, {:ok, _user}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Conta confirmada com sucesso. Já podes iniciar sessão.")
         |> push_navigate(to: ~p"/users/log-in")}

      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Conta confirmada com sucesso. Já podes iniciar sessão.")
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, :not_found} ->
        {:noreply,
        socket
         |> put_flash(:error, "O link de confirmação é inválido ou expirou.")
         |> push_navigate(to: ~p"/users/log-in")}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Não foi possível confirmar a conta.")
         |> push_navigate(to: ~p"/users/log-in")}
    end
  end
end
