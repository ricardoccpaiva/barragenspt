defmodule BarragensptWeb.UserLive.ResetPassword do
  use BarragensptWeb, :live_view

  alias Barragenspt.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-4">
        <div class="text-center">
          <.header>
            Nova palavra-passe
            <:subtitle>
              Define uma nova palavra-passe para <span class="font-medium">{@user.email}</span>.
            </:subtitle>
          </.header>
        </div>

        <.form for={@form} id="reset_password_form" phx-submit="reset_password">
          <.input
            field={@form[:password]}
            type="password"
            label="Nova palavra-passe"
            autocomplete="new-password"
            required
            phx-mounted={JS.focus()}
          />

          <.input
            field={@form[:password_confirmation]}
            type="password"
            label="Confirmar nova palavra-passe"
            autocomplete="new-password"
            required
          />

          <.button phx-disable-with="A guardar..." class="w-full">
            Guardar nova palavra-passe
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_reset_password_token(token) do
      changeset = Accounts.change_user_password(user, %{}, hash_password: false)

      {:ok,
       socket
       |> assign(:token, token)
       |> assign(:user, user)
       |> assign_form(changeset)}
    else
      {:ok,
       socket
       |> put_flash(:error, "O link para redefinir a palavra-passe é inválido ou expirou.")
       |> push_navigate(to: ~p"/users/reset-password")}
    end
  end

  @impl true
  def handle_event("reset_password", %{"user" => user_params}, socket) do
    case Accounts.reset_user_password(socket.assigns.token, user_params) do
      {:ok, {_user, _expired_tokens}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Palavra-passe redefinida com sucesso. Já podes iniciar sessão.")
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :update))}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "O link para redefinir a palavra-passe é inválido ou expirou.")
         |> push_navigate(to: ~p"/users/reset-password")}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: "user"))
  end
end
