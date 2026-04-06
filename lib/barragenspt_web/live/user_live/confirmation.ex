defmodule BarragensptWeb.UserLive.Confirmation do
  use BarragensptWeb, :live_view

  alias Barragenspt.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>Bem-vindo {@user.email}</.header>
        </div>

        <.form
          :if={!@user.confirmed_at}
          for={@form}
          id="confirmation_form"
          phx-mounted={JS.focus_first()}
          phx-submit="submit"
          action={~p"/users/log-in?_action=confirmed"}
          phx-trigger-action={@trigger_submit}
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <.button
            name={@form[:remember_me].name}
            value="true"
            phx-disable-with="A confirmar..."
            class="w-full"
          >
            Confirmar e manter sessão
          </.button>
          <.button
            phx-disable-with="A confirmar..."
            class="mt-2 w-full bg-slate-200 text-slate-800 hover:bg-slate-300 dark:bg-slate-700 dark:text-slate-100 dark:hover:bg-slate-600"
          >
            Confirmar e iniciar sessão só desta vez
          </.button>
        </.form>

        <.form
          :if={@user.confirmed_at}
          for={@form}
          id="login_form"
          phx-submit="submit"
          phx-mounted={JS.focus_first()}
          action={~p"/users/log-in"}
          phx-trigger-action={@trigger_submit}
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <%= if @current_scope.user do %>
            <.button phx-disable-with="A iniciar sessão..." class="w-full">
              Iniciar sessão
            </.button>
          <% else %>
            <.button
              name={@form[:remember_me].name}
              value="true"
              phx-disable-with="A iniciar sessão..."
              class="w-full"
            >
              Manter sessão neste dispositivo
            </.button>
            <.button
              phx-disable-with="A iniciar sessão..."
              class="mt-2 w-full bg-slate-200 text-slate-800 hover:bg-slate-300 dark:bg-slate-700 dark:text-slate-100 dark:hover:bg-slate-600"
            >
              Iniciar sessão só desta vez
            </.button>
          <% end %>
        </.form>

        <p
          :if={!@user.confirmed_at}
          class="mt-8 rounded-lg border border-slate-200 bg-slate-50 p-3 text-sm text-slate-600 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-400"
        >
          Dica: se preferires palavra-passe, podes configurá-la nas definições da conta.
        </p>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token, "remember_me" => "true"}, as: "user")

      {:ok, assign(socket, user: user, form: form, trigger_submit: false),
       temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "O link mágico é inválido ou expirou.")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end
