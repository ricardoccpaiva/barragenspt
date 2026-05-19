defmodule BarragensptWeb.UserLive.ForgotPassword do
  use BarragensptWeb, :live_view

  alias Barragenspt.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-4">
        <div class="text-center">
          <.header>
            Recuperar palavra-passe
            <:subtitle>
              Introduz o teu e-mail e enviamos-te um link para definires uma nova palavra-passe.
            </:subtitle>
          </.header>
        </div>

        <.form for={@form} id="forgot_password_form" phx-submit="send_email">
          <.input
            field={@form[:email]}
            type="email"
            label="E-mail"
            autocomplete="username"
            required
            phx-mounted={JS.focus()}
          />

          <.button phx-disable-with="A enviar..." class="w-full">
            Enviar instruções
          </.button>
        </.form>

        <.link
          navigate={~p"/users/log-in"}
          class="inline-flex w-full items-center justify-center rounded-lg bg-slate-200 px-4 py-2.5 text-sm font-semibold text-slate-800 hover:bg-slate-300 dark:bg-slate-700 dark:text-slate-100 dark:hover:bg-slate-600"
        >
          Voltar ao login
        </.link>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{"email" => ""}, as: "user"))}
  end

  @impl true
  def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/users/reset-password/#{&1}")
      )
    end

    {:noreply,
     socket
     |> put_flash(
       :info,
       "Se esse e-mail existir na nossa base de dados, vais receber instruções para redefinir a palavra-passe."
     )
     |> push_navigate(to: ~p"/users/log-in")}
  end
end
