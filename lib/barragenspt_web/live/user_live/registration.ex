defmodule BarragensptWeb.UserLive.Registration do
  use BarragensptWeb, :live_view

  alias Barragenspt.Accounts
  alias Barragenspt.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>
            Criar conta
            <:subtitle>
              Já tens conta?
              <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
                Inicia sessão
              </.link>.
            </:subtitle>
          </.header>
        </div>

        <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
          <.input
            field={@form[:email]}
            type="email"
            label="E-mail"
            autocomplete="username"
            required
            phx-mounted={JS.focus()}
          />

          <.button phx-disable-with="A criar conta..." class="w-full">
            Criar conta
          </.button>
        </.form>

        <div class="my-3 flex items-center gap-4 py-2 text-center text-sm text-slate-500">
          <div class="h-px flex-1 bg-slate-200 dark:bg-slate-600"></div>
          <span>ou</span>
          <div class="h-px flex-1 bg-slate-200 dark:bg-slate-600"></div>
        </div>

        <.link
          href={~p"/auth/google"}
          class="inline-flex w-full items-center justify-center gap-2 rounded-lg border border-slate-300 bg-white px-4 py-2.5 text-sm font-semibold text-slate-800 transition-colors hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:ring-offset-2 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100 dark:hover:bg-slate-700 dark:focus:ring-offset-slate-900"
        >
          Continuar com Google
        </.link>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: BarragensptWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_email(%User{}, %{}, validate_unique: false)

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "Foi enviado um e-mail para #{user.email}. Abre-o para confirmar a tua conta."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_email(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
