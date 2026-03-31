defmodule BarragensptWeb.UserLive.Settings do
  use BarragensptWeb, :live_view

  on_mount {BarragensptWeb.UserAuth, :require_sudo_mode}

  alias Barragenspt.Accounts
  alias Barragenspt.Accounts.Scope

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="text-center">
        <.header>
          Definições da Conta
        </.header>
      </div>
      <div class="space-y-6">
        <section class="rounded-xl border border-slate-200 bg-white p-4 text-left shadow-sm dark:border-slate-600 dark:bg-slate-800/40">
          <div class="mb-3 border-b border-slate-200 pb-3 dark:border-slate-600">
            <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">Alertas via Telegram</h2>
            <p class="mt-1 text-sm text-slate-600 dark:text-slate-400">
              Liga a tua conta Telegram para receber notificações de alertas.
            </p>
          </div>

          <%= if telegram_connected?(@current_scope.user) do %>
            <p class="text-sm text-emerald-700 dark:text-emerald-300">
              Ligado ({mask_chat_id(@current_scope.user.telegram_chat_id)})
            </p>
            <button
              id="unlink_telegram"
              type="button"
              phx-click="unlink_telegram"
              class="mt-3 rounded-lg border border-slate-300 px-3 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50 dark:border-slate-600 dark:text-slate-200 dark:hover:bg-slate-700/50"
            >
              Desligar Telegram
            </button>
          <% else %>
            <p class="text-sm text-slate-700 dark:text-slate-300">
              Clique em <strong>Ligar Telegram</strong> e envie <code>/start</code> no bot.
              A ligação é confirmada automaticamente.
            </p>

            <div class="mt-4 flex flex-wrap gap-2">
              <a
                id="start_telegram_link"
                href={@telegram_deep_link}
                target="_blank"
                rel="noopener noreferrer"
                class="rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white hover:bg-brand-700"
              >
                Ligar Telegram
              </a>
            </div>
          <% end %>
        </section>

        <section class="rounded-xl border border-slate-200 bg-white p-4 text-left shadow-sm dark:border-slate-600 dark:bg-slate-800/40">
          <div class="mb-3 border-b border-slate-200 pb-3 dark:border-slate-600">
            <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">Segurança</h2>
            <p class="mt-1 text-sm text-slate-600 dark:text-slate-400">
              Atualize a sua palavra-passe para manter a conta segura.
            </p>
          </div>

          <.form
            for={@password_form}
            id="password_form"
            action={~p"/users/update-password"}
            method="post"
            phx-change="validate_password"
            phx-submit="update_password"
            phx-trigger-action={@trigger_submit}
          >
            <input
              name={@password_form[:email].name}
              type="hidden"
              id="hidden_user_email"
              autocomplete="username"
              value={@current_email}
            />
            <.input
              field={@password_form[:password]}
              type="password"
              label="New password"
              autocomplete="new-password"
              required
            />
            <.input
              field={@password_form[:password_confirmation]}
              type="password"
              label="Confirm new password"
              autocomplete="new-password"
            />
            <.button variant="primary" phx-disable-with="Saving...">
              Save Password
            </.button>
          </.form>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    telegram_changeset = Accounts.change_user_telegram_settings(user, %{})
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    {telegram_link_token, telegram_deep_link} = ensure_telegram_link(user)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:telegram_form, to_form(telegram_changeset))
      |> assign(:telegram_bot_username, Application.get_env(:barragenspt, :telegram_bot_username))
      |> assign(:telegram_link_token, telegram_link_token)
      |> assign(:telegram_deep_link, telegram_deep_link)
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> maybe_schedule_telegram_link_poll()

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_telegram", params, socket) do
    %{"user" => user_params} = params

    telegram_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_telegram_settings(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, telegram_form: telegram_form)}
  end

  def handle_event("update_telegram", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.update_user_telegram_settings(user, user_params) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:current_scope, Scope.for_user(updated_user))
         |> assign(
           :telegram_form,
           to_form(Accounts.change_user_telegram_settings(updated_user, %{}))
         )
         |> put_flash(:info, "Telegram settings updated successfully.")}

      {:error, changeset} ->
        {:noreply, assign(socket, telegram_form: to_form(changeset, action: :insert))}
    end
  end

  def handle_event("unlink_telegram", _params, socket) do
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.update_user_telegram_settings(user, %{
           telegram_enabled: false,
           telegram_chat_id: nil
         }) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:current_scope, Scope.for_user(updated_user))
         |> assign(
           :telegram_form,
           to_form(Accounts.change_user_telegram_settings(updated_user, %{}))
         )
         |> put_flash(:info, "Telegram desligado.")}

      {:error, changeset} ->
        {:noreply, assign(socket, telegram_form: to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end

  @impl true
  def handle_info(:poll_telegram_link, socket) do
    user = socket.assigns.current_scope.user

    if telegram_connected?(user) || is_nil(socket.assigns.telegram_link_token) do
      {:noreply, socket}
    else
      token = socket.assigns.telegram_link_token

      case Accounts.get_telegram_link_token_for_user(user, token) do
        {:ok, link_token} ->
          case link_token.status do
            "linked" ->
              updated_user = Accounts.get_user!(user.id)

              {:noreply,
               socket
               |> assign(:current_scope, Scope.for_user(updated_user))
               |> assign(
                 :telegram_form,
                 to_form(Accounts.change_user_telegram_settings(updated_user, %{}))
               )
               |> assign(:telegram_link_token, nil)
               |> assign(:telegram_deep_link, nil)
               |> put_flash(:info, "Telegram ligado com sucesso.")}

            "pending" ->
              if DateTime.compare(link_token.expires_at, DateTime.utc_now()) == :gt do
                {:noreply, maybe_schedule_telegram_link_poll(socket)}
              else
                _ = Accounts.expire_telegram_link_token(link_token)
                {new_token, new_link} = ensure_telegram_link(user)

                {:noreply,
                 socket
                 |> assign(:telegram_link_token, new_token)
                 |> assign(:telegram_deep_link, new_link)
                 |> put_flash(:error, "Ligação expirada. Clique em Ligar Telegram novamente.")
                 |> maybe_schedule_telegram_link_poll()}
              end

            _ ->
              {new_token, new_link} = ensure_telegram_link(user)

              {:noreply,
               socket
               |> assign(:telegram_link_token, new_token)
               |> assign(:telegram_deep_link, new_link)
               |> maybe_schedule_telegram_link_poll()}
          end

        _ ->
          {new_token, new_link} = ensure_telegram_link(user)

          {:noreply,
           socket
           |> assign(:telegram_link_token, new_token)
           |> assign(:telegram_deep_link, new_link)
           |> maybe_schedule_telegram_link_poll()}
      end
    end
  end

  defp ensure_telegram_link(user) do
    if telegram_connected?(user) do
      {nil, nil}
    else
      case Accounts.get_pending_telegram_link_token(user) do
        {:ok, link_token} ->
          {link_token.token, telegram_deep_link(link_token.token)}

        _ ->
          case Accounts.create_telegram_link_token(user) do
            {:ok, link_token} -> {link_token.token, telegram_deep_link(link_token.token)}
            _ -> {nil, nil}
          end
      end
    end
  end

  defp telegram_deep_link(nil), do: nil

  defp telegram_deep_link(token) do
    case Application.get_env(:barragenspt, :telegram_bot_username) do
      bot when is_binary(bot) and bot != "" -> "https://t.me/#{bot}?start=#{token}"
      _ -> nil
    end
  end

  defp maybe_schedule_telegram_link_poll(socket) do
    if socket.assigns.telegram_link_token do
      Process.send_after(self(), :poll_telegram_link, 2000)
    end

    socket
  end

  defp telegram_connected?(user),
    do: user.telegram_enabled && is_binary(user.telegram_chat_id) && user.telegram_chat_id != ""

  defp mask_chat_id(nil), do: "chat desconhecido"

  defp mask_chat_id(chat_id) when is_binary(chat_id) do
    size = String.length(chat_id)

    if size <= 6 do
      chat_id
    else
      String.slice(chat_id, 0, 3) <> "..." <> String.slice(chat_id, -3, 3)
    end
  end
end
