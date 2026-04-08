defmodule BarragensptWeb.Dashboard.ApiTokensLive do
  use BarragensptWeb, :live_view

  on_mount {BarragensptWeb.UserAuth, :require_sudo_mode}

  alias Barragenspt.Accounts
  alias Barragenspt.Accounts.UserApiToken

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    {:ok,
     socket
     |> assign(:page_title, "Tokens API")
     |> refresh_tokens(user.id)
     |> assign(:selected_scopes, [])
     |> assign(:generate_modal_open?, false)
     |> assign(:plain_token_secret, nil)}
  end

  @impl true
  def handle_event("open_generate_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:generate_modal_open?, true)
     |> assign(:selected_scopes, [])}
  end

  def handle_event("close_generate_modal", _, socket) do
    {:noreply, assign(socket, :generate_modal_open?, false)}
  end

  def handle_event("toggle_scope", %{"scope" => scope}, socket) do
    allowed = UserApiToken.allowed_scopes()

    if scope not in allowed do
      {:noreply, socket}
    else
      sel = socket.assigns.selected_scopes

      new_sel =
        if scope in sel do
          List.delete(sel, scope)
        else
          if length(sel) >= 3 do
            :over
          else
            Enum.sort(sel ++ [scope])
          end
        end

      case new_sel do
        :over ->
          {:noreply, put_flash(socket, :error, "No máximo 3 âmbitos.")}

        list ->
          {:noreply, assign(socket, :selected_scopes, list)}
      end
    end
  end

  def handle_event("create_token", _params, socket) do
    user_id = socket.assigns.current_scope.user.id
    scopes = socket.assigns.selected_scopes

    if scopes == [] do
      {:noreply, put_flash(socket, :error, "Escolhe pelo menos um âmbito.")}
    else
      case Accounts.create_user_api_token(user_id, scopes) do
        {:ok, plain, _token} ->
          {:noreply,
           socket
           |> assign(:plain_token_secret, plain)
           |> assign(:selected_scopes, [])
           |> assign(:generate_modal_open?, false)
           |> refresh_tokens(user_id)
           |> put_flash(:info, "Token criado. Copia-o agora — não voltará a ser mostrado.")}

        {:error, :limit} ->
          {:noreply, put_flash(socket, :error, "Limite de 5 tokens ativos.")}

        {:error, %Ecto.Changeset{}} ->
          {:noreply,
           put_flash(socket, :error, "Não foi possível criar o token. Verifica os âmbitos.")}
      end
    end
  end

  def handle_event("dismiss_plain_token", _, socket) do
    {:noreply, assign(socket, :plain_token_secret, nil)}
  end

  def handle_event("revoke", %{"id" => id}, socket) do
    user_id = socket.assigns.current_scope.user.id

    with {token_id, ""} <- Integer.parse(id),
         {:ok, _} <- Accounts.revoke_user_api_token(user_id, token_id) do
      {:noreply,
       socket
       |> refresh_tokens(user_id)
       |> put_flash(:info, "Token revogado.")}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Não foi possível revogar o token.")}
    end
  end

  def handle_event("discard_token", %{"id" => id}, socket) do
    user_id = socket.assigns.current_scope.user.id

    with {token_id, ""} <- Integer.parse(id),
         {:ok, _} <- Accounts.discard_user_api_token(user_id, token_id) do
      {:noreply,
       socket
       |> refresh_tokens(user_id)
       |> put_flash(:info, "Token removido da tua lista.")}
    else
      {:error, :not_revoked} ->
        {:noreply, put_flash(socket, :error, "Revoga o token antes de o apagar da lista.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Não foi possível apagar o registo.")}
    end
  end

  defp refresh_tokens(socket, user_id) do
    socket
    |> assign(:tokens, Accounts.list_user_api_tokens(user_id))
    |> assign(:active_count, Accounts.count_active_user_api_tokens(user_id))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div class="flex flex-wrap items-start justify-between gap-4 sm:items-center sm:gap-6">
          <.header>
            Tokens API
            <:subtitle>
              Gera até 5 tokens ativos com âmbitos Barragens, Bacias ou Pontos de dados. Cada token só é mostrado uma vez.
            </:subtitle>
          </.header>
          <button
            type="button"
            phx-click="open_generate_modal"
            disabled={@active_count >= UserApiToken.max_active_per_user()}
            title={
              if @active_count >= UserApiToken.max_active_per_user(),
                do: "Limite de 5 tokens ativos",
                else: "Abrir formulário para gerar token"
            }
            class="inline-flex shrink-0 rounded-lg bg-brand-600 px-4 py-2 text-[13px] font-semibold text-white shadow-sm hover:bg-brand-700 disabled:cursor-not-allowed disabled:opacity-50"
          >
            Gerar token
          </button>
        </div>

        <div class="max-w-full overflow-x-auto rounded-2xl border border-slate-200/90 bg-white shadow-[0_4px_24px_-6px_rgba(15,23,42,0.12)] ring-1 ring-slate-950/[0.04] dark:border-slate-700/90 dark:bg-slate-900/45 dark:shadow-[0_8px_32px_-8px_rgba(0,0,0,0.55)] dark:ring-white/[0.06]">
          <table class="min-w-full border-collapse text-[13px]">
            <thead class="sticky top-0 z-10 border-b border-slate-200/90 bg-slate-50/90 backdrop-blur-md dark:border-slate-700/80 dark:bg-slate-950/85">
              <tr>
                <th class="px-4 py-3 text-left text-[13px] font-bold uppercase tracking-wide text-slate-500 first:pl-5 last:pr-5 dark:text-slate-400">
                  Prefixo
                </th>
                <th class="px-4 py-3 text-left text-[13px] font-bold uppercase tracking-wide text-slate-500 first:pl-5 last:pr-5 dark:text-slate-400">
                  Âmbitos
                </th>
                <th class="px-4 py-3 text-left text-[13px] font-bold uppercase tracking-wide text-slate-500 first:pl-5 last:pr-5 dark:text-slate-400">
                  Criado em
                </th>
                <th class="px-4 py-3 text-left text-[13px] font-bold uppercase tracking-wide text-slate-500 first:pl-5 last:pr-5 dark:text-slate-400">
                  Revogado em
                </th>
                <th class="px-4 py-3 text-left text-[13px] font-bold uppercase tracking-wide text-slate-500 first:pl-5 last:pr-5 dark:text-slate-400">
                  Estado
                </th>
                <th class="px-4 py-3 text-left text-[13px] font-bold uppercase tracking-wide text-slate-500 first:pl-5 last:pr-5 dark:text-slate-400">
                  Ações
                </th>
              </tr>
            </thead>
            <tbody class="[&>tr:nth-child(even)]:bg-slate-50/70 [&>tr:hover]:bg-sky-50/60 dark:[&>tr:nth-child(even)]:bg-slate-800/25 dark:[&>tr:hover]:bg-slate-800/55">
              <%= if @tokens == [] do %>
                <tr class="border-b border-slate-100/90 dark:border-slate-800/70">
                  <td colspan="6" class="px-4 py-8 text-center text-slate-600 dark:text-slate-400">
                    Ainda não tens tokens. Usa «Gerar token» para criar um.
                  </td>
                </tr>
              <% else %>
                <%= for t <- @tokens do %>
                  <tr class="border-b border-slate-100/90 transition-colors duration-200 last:border-b-0 dark:border-slate-800/70">
                    <td class="px-4 py-2 align-middle font-mono text-[12px] text-slate-800 first:pl-5 last:pr-5 dark:text-slate-200">
                      {t.token_prefix}…
                    </td>
                    <td class="px-4 py-2 align-middle text-slate-700 first:pl-5 last:pr-5 dark:text-slate-300">
                      {scope_labels_joined(t.scopes)}
                    </td>
                    <td class="px-4 py-2 align-middle tabular-nums text-slate-600 first:pl-5 last:pr-5 dark:text-slate-400">
                      {format_dt(t.created_at)}
                    </td>
                    <td class="px-4 py-2 align-middle tabular-nums text-slate-600 first:pl-5 last:pr-5 dark:text-slate-400">
                      <%= if t.revoked_at do %>
                        {format_dt(t.revoked_at)}
                      <% else %>
                        —
                      <% end %>
                    </td>
                    <td class="px-4 py-2 align-middle first:pl-5 last:pr-5">
                      <%= if UserApiToken.active?(t) do %>
                        <span class="inline-flex rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800 dark:bg-green-900/40 dark:text-green-200">
                          Ativo
                        </span>
                      <% else %>
                        <span class="inline-flex rounded-full bg-slate-200 px-2 py-0.5 text-xs font-medium text-slate-800 dark:bg-slate-600 dark:text-slate-100">
                          Revogado
                        </span>
                      <% end %>
                    </td>
                    <td class="px-4 py-2 align-middle first:pl-5 last:pr-5">
                      <%= if UserApiToken.active?(t) do %>
                        <button
                          type="button"
                          phx-click="revoke"
                          phx-value-id={to_string(t.id)}
                          data-confirm="Revogar este token? As integrações que o usam deixam de funcionar."
                          class="text-[13px] font-semibold text-rose-600 hover:underline dark:text-rose-400"
                        >
                          Revogar
                        </button>
                      <% else %>
                        <button
                          type="button"
                          phx-click="discard_token"
                          phx-value-id={to_string(t.id)}
                          data-confirm="Apagar da tua lista? O token continua revogado."
                          class="inline-flex rounded-lg p-1.5 text-slate-500 hover:bg-slate-100 hover:text-rose-600 dark:text-slate-400 dark:hover:bg-slate-700 dark:hover:text-rose-400"
                          aria-label="Apagar da lista"
                          title="Apagar da lista"
                        >
                          <.icon name="hero-trash" class="size-4" />
                        </button>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              <% end %>
            </tbody>
          </table>
        </div>

        <.link
          navigate={~p"/dashboard"}
          class="inline-flex text-sm font-medium text-brand-600 hover:underline dark:text-brand-400"
        >
          ← Painel
        </.link>
      </div>

      <%= if @generate_modal_open? do %>
        <div
          class="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto p-4 sm:items-center"
          role="dialog"
          aria-modal="true"
          aria-labelledby="api-token-generate-title"
        >
          <div
            class="absolute inset-0 bg-slate-900/60 backdrop-blur-[2px] dark:bg-slate-950/70"
            phx-click="close_generate_modal"
          >
          </div>
          <div class="relative mt-4 w-full max-w-md rounded-2xl border border-slate-200 bg-white p-5 shadow-xl dark:border-slate-600 dark:bg-slate-800 sm:mt-0 sm:p-6">
            <div class="flex items-start justify-between gap-3">
              <h2
                id="api-token-generate-title"
                class="text-lg font-semibold text-slate-900 dark:text-slate-100"
              >
                Gerar token
              </h2>
              <button
                type="button"
                phx-click="close_generate_modal"
                class="rounded-lg p-1 text-slate-500 hover:bg-slate-100 hover:text-slate-900 dark:hover:bg-slate-700 dark:hover:text-white"
                aria-label="Fechar"
              >
                <.icon name="hero-x-mark" class="size-5" />
              </button>
            </div>
            <p class="mt-2 text-sm text-slate-600 dark:text-slate-400">
              Escolhe 1 a 3 âmbitos. O token em claro só aparece após criar.
            </p>

            <div class="mt-4 flex flex-col gap-2" role="group" aria-label="Âmbitos do token">
              <%= for scope <- UserApiToken.allowed_scopes() do %>
                <div
                  class="flex cursor-pointer items-center gap-3 rounded-lg border border-slate-200 bg-white px-3 py-2.5 transition-colors hover:bg-slate-50 dark:border-slate-600 dark:bg-slate-900/40 dark:hover:bg-slate-700/50"
                  phx-click="toggle_scope"
                  phx-value-scope={scope}
                >
                  <input
                    type="checkbox"
                    id={"api-token-scope-#{scope}"}
                    checked={scope in @selected_scopes}
                    class="pointer-events-none h-4 w-4 shrink-0 rounded border-slate-300 text-brand-600 focus:ring-brand-500 dark:border-slate-500 dark:bg-slate-800 dark:ring-offset-slate-800"
                    tabindex="-1"
                    aria-hidden="true"
                  />
                  <label
                    for={"api-token-scope-#{scope}"}
                    class="pointer-events-none flex-1 cursor-pointer text-[13px] font-medium text-slate-800 dark:text-slate-200"
                  >
                    {Map.fetch!(UserApiToken.scope_labels(), scope)}
                  </label>
                </div>
              <% end %>
            </div>

            <p class="mt-3 text-xs text-slate-500 dark:text-slate-400">
              {length(@selected_scopes)}/3 âmbitos · {max(
                0,
                UserApiToken.max_active_per_user() - @active_count
              )} tokens disponíveis
            </p>

            <div class="mt-5 flex flex-wrap gap-2">
              <button
                type="button"
                phx-click="create_token"
                disabled={
                  @active_count >= UserApiToken.max_active_per_user() or @selected_scopes == []
                }
                class="inline-flex rounded-lg bg-brand-600 px-4 py-2 text-[13px] font-semibold text-white hover:bg-brand-700 disabled:cursor-not-allowed disabled:opacity-50"
              >
                Gerar token
              </button>
              <button
                type="button"
                phx-click="close_generate_modal"
                class="inline-flex rounded-lg border border-slate-300 px-4 py-2 text-[13px] font-semibold text-slate-700 hover:bg-slate-50 dark:border-slate-600 dark:text-slate-200 dark:hover:bg-slate-700/60"
              >
                Cancelar
              </button>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @plain_token_secret do %>
        <div
          class="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto p-4 sm:items-center"
          role="dialog"
          aria-modal="true"
          aria-labelledby="api-token-secret-title"
        >
          <div
            class="absolute inset-0 bg-slate-900/60 backdrop-blur-[2px] dark:bg-slate-950/70"
            phx-click="dismiss_plain_token"
          >
          </div>
          <div class="relative mt-4 w-full max-w-lg rounded-2xl border border-slate-200 bg-white p-5 shadow-xl dark:border-slate-600 dark:bg-slate-800 sm:mt-0 sm:p-6">
            <h2
              id="api-token-secret-title"
              class="text-lg font-semibold text-slate-900 dark:text-slate-100"
            >
              Copia o teu token
            </h2>
            <p class="mt-2 text-sm text-slate-600 dark:text-slate-400">
              Este valor não volta a ser mostrado. Guarda-o num gestor de segredos.
            </p>
            <pre class="mt-4 overflow-x-auto rounded-lg bg-slate-100 p-3 text-xs text-slate-900 dark:bg-slate-900 dark:text-slate-100"><%= @plain_token_secret %></pre>
            <div class="mt-4 flex flex-wrap gap-2">
              <button
                type="button"
                id="api-token-copy-btn"
                phx-hook="CopyButton"
                data-copy-text={@plain_token_secret}
                class="inline-flex rounded-lg bg-brand-600 px-3 py-2 text-sm font-semibold text-white hover:bg-brand-700"
              >
                Copiar
              </button>
              <button
                type="button"
                phx-click="dismiss_plain_token"
                class="inline-flex rounded-lg border border-slate-300 px-3 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-50 dark:border-slate-600 dark:text-slate-200 dark:hover:bg-slate-700/60"
              >
                Fechar
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end

  defp format_dt(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
  end

  defp format_dt(%NaiveDateTime{} = ndt) do
    NaiveDateTime.to_string(ndt)
  end

  defp format_dt(nil), do: "—"

  defp scope_labels_joined(scopes) when is_list(scopes) do
    labels = UserApiToken.scope_labels()

    scopes
    |> Enum.map(&Map.fetch!(labels, &1))
    |> Enum.join(", ")
  end
end
