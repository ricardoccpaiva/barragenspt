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
            <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">
              Tipos de Notificação
            </h2>
            <p class="mt-1 text-sm text-slate-600 dark:text-slate-400">
              Ative ou pause cada canal de entrega de alertas.
            </p>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-slate-200 text-sm dark:divide-slate-700">
              <thead>
                <tr class="text-left text-xs uppercase tracking-wide text-slate-500 dark:text-slate-400">
                  <th class="py-2 pr-3 font-medium">Canal</th>
                  <th class="px-3 py-2 font-medium">Destino</th>
                  <th class="px-3 py-2 font-medium">Estado</th>
                  <th class="px-3 py-2 font-medium text-right">Ações</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100 dark:divide-slate-700/70">
                <tr>
                  <td class="py-3 pr-3 font-semibold text-slate-900 dark:text-slate-100">E-mail</td>
                  <td class="px-3 py-3 text-slate-600 dark:text-slate-300">{@current_scope.user.email}</td>
                  <td class="px-3 py-3">
                    <span class={[
                      "inline-flex rounded-full px-2 py-0.5 text-xs font-medium",
                      @current_scope.user.email_notifications_enabled &&
                        "bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-200",
                      !@current_scope.user.email_notifications_enabled &&
                        "bg-slate-200 text-slate-800 dark:bg-slate-600 dark:text-slate-100"
                    ]}>
                      {if @current_scope.user.email_notifications_enabled, do: "Ativo", else: "Pausado"}
                    </span>
                  </td>
                  <td class="px-3 py-3">
                    <div class="inline-flex w-full items-center justify-end gap-1">
                      <button
                        id="toggle_email_notifications"
                        type="button"
                        phx-click="toggle_email_notifications"
                        class="inline-flex rounded-lg p-1.5 text-brand-600 hover:bg-brand-50 focus:outline-none focus:ring-2 focus:ring-brand-500 dark:text-brand-400 dark:hover:bg-brand-900/30"
                        aria-label={
                          if @current_scope.user.email_notifications_enabled,
                            do: "Pausar notificações por e-mail",
                            else: "Retomar notificações por e-mail"
                        }
                        title={
                          if @current_scope.user.email_notifications_enabled, do: "Pausar", else: "Retomar"
                        }
                      >
                        <%= if @current_scope.user.email_notifications_enabled do %>
                          <.icon name="hero-pause" class="size-5" />
                        <% else %>
                          <.icon name="hero-play" class="size-5" />
                        <% end %>
                      </button>
                    </div>
                  </td>
                </tr>

                <tr>
                  <td class="py-3 pr-3 font-semibold text-slate-900 dark:text-slate-100">Telegram</td>
                  <td class="px-3 py-3 text-slate-600 dark:text-slate-300">
                    <%= if telegram_connected?(@current_scope.user) do %>
                      {@current_scope.user.telegram_chat_id}
                    <% else %>
                      Conta não ligada
                    <% end %>
                  </td>
                  <td class="px-3 py-3">
                    <span class={[
                      "inline-flex rounded-full px-2 py-0.5 text-xs font-medium",
                      telegram_active?(@current_scope.user) &&
                        "bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-200",
                      !telegram_active?(@current_scope.user) &&
                        "bg-slate-200 text-slate-800 dark:bg-slate-600 dark:text-slate-100"
                    ]}>
                      <%= cond do %>
                        <% telegram_active?(@current_scope.user) -> %>
                          Ativo
                        <% telegram_connected?(@current_scope.user) -> %>
                          Pausado
                        <% true -> %>
                          Desligado
                      <% end %>
                    </span>
                  </td>
                  <td class="px-3 py-3">
                    <div class="inline-flex w-full items-center justify-end gap-1">
                      <%= if telegram_connected?(@current_scope.user) do %>
                        <button
                          id="unlink_telegram"
                          type="button"
                          phx-click="unlink_telegram"
                          class="inline-flex rounded-lg p-1.5 text-red-600 hover:bg-red-50 focus:outline-none focus:ring-2 focus:ring-red-500 dark:text-red-400 dark:hover:bg-red-900/25"
                          aria-label="Desligar conta Telegram"
                          title="Desligar conta"
                        >
                          <.icon name="hero-trash" class="size-5" />
                        </button>
                        <button
                          id="toggle_telegram_notifications"
                          type="button"
                          phx-click="toggle_telegram_notifications"
                          class="inline-flex rounded-lg p-1.5 text-brand-600 hover:bg-brand-50 focus:outline-none focus:ring-2 focus:ring-brand-500 dark:text-brand-400 dark:hover:bg-brand-900/30"
                          aria-label={
                            if telegram_active?(@current_scope.user),
                              do: "Pausar notificações por Telegram",
                              else: "Retomar notificações por Telegram"
                          }
                          title={if telegram_active?(@current_scope.user), do: "Pausar", else: "Retomar"}
                        >
                          <%= if telegram_active?(@current_scope.user) do %>
                            <.icon name="hero-pause" class="size-5" />
                          <% else %>
                            <.icon name="hero-play" class="size-5" />
                          <% end %>
                        </button>
                      <% else %>
                        <a
                          id="start_telegram_link"
                          href={@telegram_deep_link}
                          target="_blank"
                          rel="noopener noreferrer"
                          class="rounded-lg bg-brand-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-brand-700"
                        >
                          Ligar Telegram
                        </a>
                      <% end %>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
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
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    {telegram_link_token, telegram_deep_link} = ensure_telegram_link(user)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:telegram_bot_username, Application.get_env(:barragenspt, :telegram_bot_username))
      |> assign(:telegram_link_token, telegram_link_token)
      |> assign(:telegram_deep_link, telegram_deep_link)
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> maybe_schedule_telegram_link_poll()

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_email_notifications", _params, socket) do
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user, -sudo_mode_validity_minutes())

    case Accounts.update_user_telegram_settings(user, %{
           email_notifications_enabled: !user.email_notifications_enabled
         }) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:current_scope, Scope.for_user(updated_user))
         |> put_flash(:info, "Notificações por e-mail atualizadas.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Não foi possível atualizar notificações por e-mail.")}
    end
  end

  @impl true
  def handle_event("toggle_telegram_notifications", _params, socket) do
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user, -sudo_mode_validity_minutes())

    if telegram_connected?(user) do
      case Accounts.update_user_telegram_settings(user, %{telegram_enabled: !user.telegram_enabled}) do
        {:ok, updated_user} ->
          {:noreply,
           socket
           |> assign(:current_scope, Scope.for_user(updated_user))
           |> put_flash(:info, "Notificações por Telegram atualizadas.")}

        {:error, _changeset} ->
          {:noreply,
           put_flash(socket, :error, "Não foi possível atualizar notificações por Telegram.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Primeiro ligue a conta Telegram.")}
    end
  end

  def handle_event("unlink_telegram", _params, socket) do
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user, -sudo_mode_validity_minutes())

    case Accounts.update_user_telegram_settings(user, %{
           telegram_enabled: false,
           telegram_chat_id: nil
         }) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:current_scope, Scope.for_user(updated_user))
         |> put_flash(:info, "Telegram desligado.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Não foi possível desligar o Telegram.")}
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
    true = Accounts.sudo_mode?(user, -sudo_mode_validity_minutes())

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
    do: is_binary(user.telegram_chat_id) && user.telegram_chat_id != ""

  defp telegram_active?(user),
    do: telegram_connected?(user) && user.telegram_enabled

  defp sudo_mode_validity_minutes do
    case Application.get_env(:barragenspt, :sudo_mode_validity_minutes, 1440) do
      m when is_integer(m) and m > 0 -> m
      _ -> 1440
    end
  end
end
