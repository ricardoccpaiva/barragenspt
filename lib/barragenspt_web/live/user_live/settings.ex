defmodule BarragensptWeb.UserLive.Settings do
  use BarragensptWeb, :live_view

  on_mount {BarragensptWeb.UserAuth, :require_sudo_mode}

  alias Barragenspt.Accounts
  alias Barragenspt.Accounts.Scope
  alias Barragenspt.Services.R2
  alias BarragensptWeb.UserAvatar

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
            <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">Perfil</h2>
            <p class="mt-1 text-sm text-slate-600 dark:text-slate-400">
              Defina o nome apresentado na aplicação e atualize a foto de perfil.
            </p>
          </div>

          <div class="flex flex-col gap-5 lg:flex-row lg:items-start">
            <%= if src = UserAvatar.image_src(@current_scope.user) do %>
              <img
                src={src}
                alt="Foto de perfil"
                loading="lazy"
                decoding="async"
                referrerpolicy="no-referrer"
                class="h-20 w-20 shrink-0 rounded-full object-cover ring-1 ring-slate-200/80 dark:ring-slate-600"
              />
            <% else %>
              <div class="inline-flex h-20 w-20 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-sky-500 to-blue-600 text-2xl font-bold text-white">
                {case to_string(@current_scope.user.display_name || @current_scope.user.email || "") |> String.trim() do
                  e when is_binary(e) and e != "" -> e |> String.first() |> String.upcase()
                  _ -> "U"
                end}
              </div>
            <% end %>

            <div class="min-w-0 flex-1 space-y-5">
              <.form
                for={@display_name_form}
                id="display_name_form"
                phx-change="validate_display_name"
                phx-submit="update_display_name"
                class="max-w-xl"
              >
                <label
                  for={@display_name_form[:display_name].id}
                  class="mb-1.5 block text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  Nome
                </label>
                <div class="flex flex-wrap items-center gap-2">
                  <input
                    id={@display_name_form[:display_name].id}
                    name={@display_name_form[:display_name].name}
                    type="text"
                    value={@display_name_form[:display_name].value}
                    placeholder="Ex. Ricardo Paiva"
                    class="h-10 w-full max-w-[18rem] rounded-lg border border-slate-300 bg-white px-3 text-sm font-medium text-slate-900 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500 dark:border-slate-600 dark:bg-slate-900 dark:text-slate-100"
                  />
                  <.button
                    variant="primary"
                    phx-disable-with="A guardar..."
                    class="h-10 min-w-[5.5rem] px-3 whitespace-nowrap"
                  >
                    Gravar
                  </.button>
                </div>
                <%= for error <- @display_name_form[:display_name].errors do %>
                  <p class="mt-1 text-sm text-rose-600 dark:text-rose-400">{translate_error(error)}</p>
                <% end %>
              </.form>

              <div class="border-t border-slate-200 pt-4 dark:border-slate-600">
                <p class="mb-2 text-sm font-semibold text-slate-900 dark:text-slate-100">Foto de perfil</p>
                <.form
                  id="avatar_form"
                  for={%{}}
                  phx-change="validate_avatar_upload"
                  phx-submit="upload_avatar"
                  class="w-full max-w-2xl"
                >
                  <div class="space-y-3">
                    <div class="grid gap-2 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-center">
                      <div class="relative min-w-[12rem] flex-1 rounded-lg border border-slate-200 bg-slate-50/70 px-3 py-2 pr-12 text-sm text-slate-600 dark:border-slate-600 dark:bg-slate-800/40 dark:text-slate-300">
                        <div class="truncate">
                          <%= if @uploads.avatar.entries == [] do %>
                            Nenhum ficheiro selecionado
                          <% else %>
                            <%= for entry <- @uploads.avatar.entries do %>
                              <span>{entry.client_name}</span>
                            <% end %>
                          <% end %>
                        </div>

                        <label class="absolute inset-y-1.5 right-1.5 inline-flex w-9 cursor-pointer items-center justify-center rounded-md border border-slate-300 bg-white text-slate-600 transition hover:bg-slate-100 dark:border-slate-600 dark:bg-slate-700 dark:text-slate-200 dark:hover:bg-slate-600">
                          <.icon name="hero-pencil-square" class="size-4" />
                          <span class="sr-only">Escolher imagem</span>
                          <.live_file_input
                            upload={@uploads.avatar}
                            class="absolute inset-0 h-full w-full cursor-pointer opacity-0"
                          />
                        </label>
                      </div>

                      <.button
                        variant="primary"
                        phx-disable-with="A enviar..."
                        class="h-10 px-4 whitespace-nowrap"
                      >
                        Atualizar foto
                      </.button>
                    </div>

                    <p class="text-xs text-slate-500 dark:text-slate-400">
                      Formatos aceites: PNG, JPG e WebP. Tamanho máximo: 5 MB.
                    </p>

                    <%= for entry <- @uploads.avatar.entries do %>
                      <%= for error <- upload_errors(@uploads.avatar, entry) do %>
                        <p class="text-xs text-red-600 dark:text-red-400">
                          {avatar_upload_error_to_message(error)}
                        </p>
                      <% end %>
                    <% end %>
                    <%= for error <- upload_errors(@uploads.avatar) do %>
                      <p class="text-xs text-red-600 dark:text-red-400">
                        {avatar_upload_error_to_message(error)}
                      </p>
                    <% end %>
                  </div>
                </.form>
              </div>
            </div>
          </div>
        </section>

        <section class="rounded-xl border border-slate-200 bg-white p-4 text-left shadow-sm dark:border-slate-600 dark:bg-slate-800/40">
          <div class="mb-3 border-b border-slate-200 pb-3 dark:border-slate-600">
            <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">
              Tipos de Notificação
            </h2>
            <p class="mt-1 text-sm text-slate-600 dark:text-slate-400">
              Ative ou pause cada canal de entrega de notificações.
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
                  <td class="px-3 py-3 text-slate-600 dark:text-slate-300">
                    {@current_scope.user.email}
                  </td>
                  <td class="px-3 py-3">
                    <span class={[
                      "inline-flex rounded-full px-2 py-0.5 text-xs font-medium",
                      @current_scope.user.email_notifications_enabled &&
                        "bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-200",
                      !@current_scope.user.email_notifications_enabled &&
                        "bg-slate-200 text-slate-800 dark:bg-slate-600 dark:text-slate-100"
                    ]}>
                      {if @current_scope.user.email_notifications_enabled,
                        do: "Ativo",
                        else: "Pausado"}
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
                          if @current_scope.user.email_notifications_enabled,
                            do: "Pausar",
                            else: "Retomar"
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
                          title={
                            if telegram_active?(@current_scope.user), do: "Pausar", else: "Retomar"
                          }
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
            class="max-w-[18rem]"
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
              class="text-sm"
              required
            />
            <.input
              field={@password_form[:password_confirmation]}
              type="password"
              label="Confirm new password"
              autocomplete="new-password"
              class="text-sm"
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
    display_name_changeset = Accounts.change_user_display_name(user, display_name_form_attrs(user))

    {telegram_link_token, telegram_deep_link} = ensure_telegram_link(user)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:telegram_bot_username, Application.get_env(:barragenspt, :telegram_bot_username))
      |> assign(:telegram_link_token, telegram_link_token)
      |> assign(:telegram_deep_link, telegram_deep_link)
      |> assign(:display_name_form, to_form(display_name_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> allow_upload(:avatar,
        accept: ~w(.png .jpg .jpeg .webp),
        max_entries: 1,
        max_file_size: 5_000_000
      )
      |> maybe_schedule_telegram_link_poll()

    {:ok, socket}
  end

  def handle_event("validate_avatar_upload", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("validate_display_name", %{"user" => user_params}, socket) do
    display_name_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_display_name(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, display_name_form: display_name_form)}
  end

  def handle_event("update_display_name", %{"user" => user_params}, socket) do
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user, -sudo_mode_validity_minutes())

    case Accounts.update_user_display_name(user, user_params) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:current_scope, Scope.for_user(updated_user))
         |> assign(
           :display_name_form,
           to_form(Accounts.change_user_display_name(updated_user, display_name_form_attrs(updated_user)))
         )
         |> put_flash(:info, "Display name atualizado.")}

      {:error, changeset} ->
        {:noreply, assign(socket, display_name_form: to_form(changeset, action: :validate))}
    end
  end

  def handle_event("upload_avatar", _params, socket) do
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user, -sudo_mode_validity_minutes())

    cond do
      avatar_upload_errors_present?(socket) ->
        {:noreply, put_flash(socket, :error, "A imagem selecionada não é válida.")}

      socket.assigns.uploads.avatar.entries == [] ->
        {:noreply, put_flash(socket, :error, "Selecione uma imagem para carregar.")}

      true ->
        results =
          consume_uploaded_entries(socket, :avatar, fn %{path: local_path}, entry ->
            remote_path = avatar_remote_path(user, entry.client_name)

            case upload_avatar_to_r2(local_path, remote_path) do
              :ok ->
                case build_r2_public_url(remote_path) do
                  {:ok, avatar_url} -> {:ok, {:ok, avatar_url}}
                  {:error, reason} -> {:ok, {:error, reason}}
                end

              {:error, reason} ->
                {:ok, {:error, reason}}
            end
          end)

        case results do
          [{:ok, avatar_url}] ->
            case Accounts.update_user_avatar(user, avatar_url) do
              {:ok, updated_user} ->
                {:noreply,
                 socket
                 |> assign(:current_scope, Scope.for_user(updated_user))
                 |> put_flash(:info, "Foto de perfil atualizada com sucesso.")}

              {:error, _changeset} ->
                {:noreply,
                 put_flash(socket, :error, "Não foi possível guardar a foto de perfil.")}
            end

          [{:error, reason}] ->
            reason |> IO.inspect(label: "Avatar upload error------->")
            {:noreply, put_flash(socket, :error, "Falha no upload da foto de perfil.")}

          _ ->
            {:noreply, put_flash(socket, :error, "Não foi possível processar a imagem.")}
        end
    end
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
        {:noreply,
         put_flash(socket, :error, "Não foi possível atualizar notificações por e-mail.")}
    end
  end

  @impl true
  def handle_event("toggle_telegram_notifications", _params, socket) do
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user, -sudo_mode_validity_minutes())

    if telegram_connected?(user) do
      case Accounts.update_user_telegram_settings(user, %{
             telegram_enabled: !user.telegram_enabled
           }) do
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

  defp avatar_upload_errors_present?(socket) do
    upload = socket.assigns.uploads.avatar

    upload_errors(upload) != [] ||
      (upload.entries != [] &&
         Enum.any?(upload.entries, fn entry ->
           upload_errors(upload, entry) != []
         end))
  end

  defp avatar_upload_error_to_message(:not_accepted),
    do: "Formato inválido. Use PNG, JPG ou WebP."

  defp avatar_upload_error_to_message(:too_large),
    do: "Imagem demasiado grande. O limite é 5 MB."

  defp avatar_upload_error_to_message(:too_many_files),
    do: "Só pode carregar um ficheiro."

  defp avatar_upload_error_to_message(_),
    do: "Não foi possível validar o ficheiro selecionado."

  defp avatar_remote_path(user, client_name) do
    ext =
      client_name
      |> Path.extname()
      |> String.downcase()
      |> case do
        ".jpeg" -> ".jpg"
        ".png" -> ".png"
        ".jpg" -> ".jpg"
        ".webp" -> ".webp"
        _ -> ".jpg"
      end

    "/users/avatars/#{user.id}/#{UUID.uuid4()}#{ext}"
  end

  defp upload_avatar_to_r2(local_path, remote_path) do
    client = Application.get_env(:barragenspt, :r2_upload_client, R2)

    try do
      _ = client.upload(local_path, remote_path)
      :ok
    rescue
      _ -> {:error, :upload_failed}
    catch
      _, _ -> {:error, :upload_failed}
    end
  end

  defp build_r2_public_url(remote_path) do
    R2.public_url(remote_path)
  end

  defp display_name_form_attrs(user) do
    %{"display_name" => to_string(user.display_name || user.email || "")}
  end

  defp sudo_mode_validity_minutes do
    case Application.get_env(:barragenspt, :sudo_mode_validity_minutes, 1440) do
      m when is_integer(m) and m > 0 -> m
      _ -> 1440
    end
  end
end
