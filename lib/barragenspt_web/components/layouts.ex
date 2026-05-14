defmodule BarragensptWeb.Layouts do
  @moduledoc false
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: BarragensptWeb.Endpoint,
    router: BarragensptWeb.Router,
    statics: BarragensptWeb.static_paths()

  import BarragensptWeb.CoreComponents

  alias BarragensptWeb.UserAvatar

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :mode, :atom, default: :default
  slot :sidebar
  slot :inner_block, required: true

  def app(assigns) do
    assigns =
      assigns
      |> assign(:signed_in?, signed_in?(assigns.current_scope))
      |> assign(:dashboard_sidebar_items, dashboard_sidebar_items(assigns.current_scope))

    ~H"""
    <div class="min-h-screen bg-slate-50 text-slate-800 dark:bg-slate-900 dark:text-slate-100">
      <%= if @mode == :map do %>
        <div
          id="app-shell-backdrop"
          class="fixed inset-0 z-30 hidden bg-slate-900/50 md:hidden"
          onclick="window.toggleAppShellSidebar && window.toggleAppShellSidebar(false)"
        >
        </div>

        <button
          type="button"
          class="fixed left-2 top-2 z-[35] inline-flex h-10 w-10 items-center justify-center rounded-xl bg-white/90 text-slate-700 shadow-card dark:bg-slate-800/90 dark:text-slate-200 md:hidden"
          onclick="window.toggleAppShellSidebar && window.toggleAppShellSidebar(true)"
          aria-label="Abrir navegação"
        >
          <svg
            class="h-5 w-5"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
            aria-hidden="true"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M4 7h16M4 12h16M4 17h16" />
          </svg>
        </button>

        <aside id="app-shell-sidebar" class={map_sidebar_classes()}>
          <div class="flex items-center gap-2 min-w-0 pb-1.5 border-b border-slate-200/80 dark:border-slate-600/80">
            <div
              class="sidebar-logo w-8 h-8 shrink-0 bg-brand-600 dark:bg-brand-400"
              style={"--logo-url: url('#{~p"/images/droplets.svg"}')"}
            />
            <div class="leading-none min-w-0 flex-1">
              <p class="logo-type text-[34px] text-slate-600 dark:text-slate-300 font-semibold mt-[12px]">
                BARRAGENS.PT
              </p>
            </div>
          </div>

          <div class="flex min-h-0 flex-1 flex-col pt-2">
            <%= if @sidebar != [] do %>
              {render_slot(@sidebar)}
            <% end %>
          </div>
        </aside>
      <% end %>

      <div id="app-top-chrome" class={top_chrome_outer_classes(@mode)}>
        <div class={top_chrome_inner_classes(@mode)}>
          <%= if @mode != :map and @signed_in? do %>
            <div class="flex min-w-0 shrink-0 items-center gap-2">
              <div
                id="dashboard-app-nav"
                phx-hook="NavRouteActive"
                class="inline-flex min-h-10 max-w-[calc(100vw-10rem)] flex-nowrap items-center gap-0.5 overflow-x-auto overflow-y-visible rounded-xl border border-slate-200 bg-white/90 p-1 shadow-card md:overflow-visible [-ms-overflow-style:none] [scrollbar-width:none] dark:border-slate-600 dark:bg-slate-800/90 [&::-webkit-scrollbar]:hidden"
              >
                <%= for item <- @dashboard_sidebar_items do %>
                  <%= if Map.get(item, :children, []) != [] do %>
                    <div
                      id={"dashboard-nav-menu-#{item.label |> String.downcase() |> String.replace(" ", "-")}"}
                      class="group relative shrink-0"
                    >
                      <div
                        data-nav-paths={
                          Enum.join([item.path | Enum.map(item.children, & &1.path)], ",")
                        }
                        class="inline-flex h-8 items-center gap-1 rounded-lg px-2.5 text-sm font-semibold leading-none text-slate-500 hover:bg-slate-100/90 dark:text-slate-400 dark:hover:bg-slate-700/60"
                      >
                        <.icon name={item.icon} class="h-3.5 w-3.5 shrink-0 opacity-80" />
                        <span>{item.label}</span>
                      </div>

                      <div class="invisible absolute left-0 top-full z-50 w-40 pt-1 opacity-0 transition-all duration-150 group-hover:visible group-hover:opacity-100">
                        <div class="overflow-hidden rounded-lg border border-slate-200 bg-white py-1 shadow-lg dark:border-slate-600 dark:bg-slate-800">
                          <%= for child <- item.children do %>
                            <.link
                              navigate={child.path}
                              class="flex items-center px-3 py-2 text-sm font-semibold text-slate-600 hover:bg-slate-100 hover:text-slate-900 dark:text-slate-300 dark:hover:bg-slate-700/70 dark:hover:text-slate-50"
                            >
                              {child.label}
                            </.link>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  <% else %>
                    <.link
                      navigate={item.path}
                      data-nav-path={item.path}
                      class="inline-flex h-8 shrink-0 items-center gap-1 rounded-lg px-2.5 text-sm font-semibold leading-none text-slate-500 hover:bg-slate-100/90 dark:text-slate-400 dark:hover:bg-slate-700/60"
                    >
                      <.icon name={item.icon} class="h-3.5 w-3.5 shrink-0 opacity-80" />
                      {item.label}
                    </.link>
                  <% end %>
                <% end %>
              </div>
            </div>
          <% end %>

          <div class={[
            "flex shrink-0 items-center gap-2.5",
            @mode != :map && "ml-auto"
          ]}>
            <div
              id="app-switcher"
              phx-hook="NavRouteActive"
              class="inline-flex h-10 items-center gap-0.5 rounded-xl border border-slate-200 bg-white/90 p-1 shadow-card dark:border-slate-600 dark:bg-slate-800/90"
            >
              <.link
                navigate={~p"/"}
                data-nav-path={~p"/"}
                class="inline-flex h-8 items-center rounded-lg px-3 text-sm font-semibold leading-none text-slate-500 transition-colors hover:bg-slate-100/90 dark:text-slate-400 dark:hover:bg-slate-700/60"
              >
                Mapa
              </.link>
              <%= if @signed_in? do %>
                <.link
                  navigate={~p"/dashboard"}
                  data-nav-path={~p"/dashboard"}
                  class="inline-flex h-8 items-center rounded-lg px-3 text-sm font-semibold leading-none text-slate-500 transition-colors hover:bg-slate-100/90 dark:text-slate-400 dark:hover:bg-slate-700/60"
                >
                  Dashboard
                </.link>
                <.link
                  navigate={~p"/status/workers"}
                  data-nav-path={~p"/status/workers"}
                  class="inline-flex h-8 items-center rounded-lg px-3 text-sm font-semibold leading-none text-slate-500 transition-colors hover:bg-slate-100/90 dark:text-slate-400 dark:hover:bg-slate-700/60"
                >
                  Status
                </.link>
              <% else %>
                <.link
                  href={~p"/dashboard"}
                  data-nav-path={~p"/dashboard"}
                  class="inline-flex h-8 items-center rounded-lg px-3 text-sm font-semibold leading-none text-slate-500 transition-colors hover:bg-slate-100/90 dark:text-slate-400 dark:hover:bg-slate-700/60"
                >
                  Dashboard
                </.link>
                <.link
                  href={~p"/status/workers"}
                  data-nav-path={~p"/status/workers"}
                  class="inline-flex h-8 items-center rounded-lg px-3 text-sm font-semibold leading-none text-slate-500 transition-colors hover:bg-slate-100/90 dark:text-slate-400 dark:hover:bg-slate-700/60"
                >
                  Status
                </.link>
              <% end %>
            </div>

            <div
              id="app-layout-dark-toggle"
              phx-hook="DarkModeToggle"
              role="group"
              aria-label="Selecionar tema"
              class="inline-flex h-10 items-center gap-0.5 rounded-xl border border-slate-200 bg-white/90 p-1 shadow-card dark:border-slate-600 dark:bg-slate-800/90"
            >
              <button
                type="button"
                data-theme-option="light"
                aria-label="Modo claro"
                aria-pressed="true"
                class="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-slate-500 transition-colors dark:text-slate-400"
              >
                <.icon name="hero-sun" class="h-3.5 w-3.5" />
              </button>
              <button
                type="button"
                data-theme-option="dark"
                aria-label="Modo escuro"
                aria-pressed="false"
                class="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-slate-500 transition-colors dark:text-slate-400"
              >
                <.icon name="hero-moon" class="h-3.5 w-3.5" />
              </button>
            </div>

            <details
              id="navbar-avatar-menu"
              class="group relative inline-flex h-10 list-none items-center rounded-xl border border-slate-200 bg-white/90 p-1 shadow-card dark:border-slate-600 dark:bg-slate-800/90"
              phx-hook="AvatarMenu"
            >
              <summary
                class="flex h-8 cursor-pointer list-none items-center justify-center rounded-lg marker:content-none [&::-webkit-details-marker]:hidden hover:bg-slate-100/80 dark:hover:bg-slate-700/50"
                aria-label={
                  if(@signed_in?, do: "Menu da conta", else: "Conta — iniciar sessão ou registo")
                }
              >
                <%= if @signed_in? do %>
                  <%= if src = UserAvatar.image_src(@current_scope.user) do %>
                    <img
                      src={src}
                      alt=""
                      loading="lazy"
                      decoding="async"
                      referrerpolicy="no-referrer"
                      class="h-8 w-8 shrink-0 rounded-lg object-cover ring-1 ring-slate-200/80 dark:ring-slate-600"
                    />
                  <% else %>
                    <span class="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-gradient-to-br from-sky-500 to-blue-600 text-xs font-bold text-white">
                      {case display_name_or_email(@current_scope.user) do
                        e when is_binary(e) and e != "" -> e |> String.first() |> String.upcase()
                        _ -> "U"
                      end}
                    </span>
                  <% end %>
                <% else %>
                  <.icon
                    name="hero-user-circle"
                    class="h-8 w-8 shrink-0 text-slate-500 dark:text-slate-400"
                  />
                <% end %>
              </summary>

              <div class="absolute right-0 top-full z-20 mt-1.5 w-44 rounded-xl border border-slate-200 bg-white p-1.5 shadow-lg dark:border-slate-600 dark:bg-slate-800">
                <%= if @signed_in? do %>
                  <.link
                    navigate={~p"/users/settings"}
                    class="block rounded-lg px-3 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-100 dark:text-slate-200 dark:hover:bg-slate-700/70"
                  >
                    Definições
                  </.link>
                  <.link
                    href={~p"/users/log-out"}
                    method="delete"
                    class="mt-1 block rounded-lg px-3 py-2 text-sm font-semibold text-rose-700 hover:bg-rose-50 dark:text-rose-300 dark:hover:bg-rose-900/30"
                  >
                    Sair
                  </.link>
                <% else %>
                  <.link
                    navigate={~p"/users/register"}
                    class="block rounded-lg px-3 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-100 dark:text-slate-200 dark:hover:bg-slate-700/70"
                  >
                    Registo
                  </.link>
                  <.link
                    navigate={~p"/users/log-in"}
                    class="mt-1 block rounded-lg px-3 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-100 dark:text-slate-200 dark:hover:bg-slate-700/70"
                  >
                    Iniciar sessão
                  </.link>
                <% end %>
              </div>
            </details>
          </div>
        </div>
      </div>

      <div id="app-main-wrapper" class={main_wrapper_classes(@mode)}>
        <main id="app-main-content" class={main_content_classes(@mode)}>
          <.flash_group flash={@flash} />
          {render_slot(@inner_block)}
        </main>

        <%= if @mode != :map do %>
          <footer class="mx-auto mt-8 flex w-full max-w-[1600px] items-center justify-end border-t border-slate-200 pt-4 text-xs text-slate-500 dark:border-slate-700 dark:text-slate-400">
            <.link
              href="/tos.html"
              class="font-medium hover:text-slate-700 hover:underline dark:hover:text-slate-200"
            >
              Termos
            </.link>
          </footer>
        <% end %>
      </div>

      <%= if @mode != :map do %>
        <.beta_corner_notice />
      <% end %>
    </div>
    """
  end

  def beta_corner_notice(assigns) do
    ~H"""
    <div
      class="pointer-events-none fixed bottom-0 right-0 z-40 h-[6.5rem] w-[6.5rem] overflow-hidden sm:h-[7.25rem] sm:w-[7.25rem]"
      role="status"
      aria-live="polite"
    >
      <span class="sr-only">
        Versão beta experimental. Funcionalidades e dados podem mudar.
      </span>
      <%!-- Triângulo no vértice: face escura da fita por baixo --%>
      <div
        class="absolute bottom-0 right-0 z-0 size-0 border-b-[18px] border-l-[18px] border-b-red-950/35 border-l-transparent dark:border-b-red-950/55"
        aria-hidden="true"
      >
      </div>
      <%!-- Fita diagonal (estilo marcador de caderno) --%>
      <div
        class="absolute bottom-[0.85rem] right-[-2.65rem] z-[1] flex w-[11.5rem] items-center justify-center border-y border-white/30 bg-gradient-to-r from-rose-600 via-red-600 to-red-700 px-10 py-2 shadow-[inset_0_1px_0_rgba(255,255,255,0.3),0_3px_10px_rgba(127,29,29,0.35)] -rotate-45 dark:border-white/15 dark:from-rose-700 dark:via-red-700 dark:to-red-900 dark:shadow-[inset_0_1px_0_rgba(255,255,255,0.12),0_3px_12px_rgba(0,0,0,0.45)] sm:bottom-[1rem] sm:right-[-2.85rem] sm:w-[13rem] sm:px-11 sm:py-2.5"
        aria-hidden="true"
      >
        <span class="font-sans text-[13px] font-semibold uppercase leading-none tracking-wide text-white antialiased [padding-inline-start:0.025em]">
          Beta
        </span>
      </div>
    </div>
    """
  end

  defp map_sidebar_classes do
    "fixed z-40 w-[80%] max-w-[279px] -translate-x-[calc(100%+1rem)] md:translate-x-0 md:max-w-none md:w-[317px] inset-2 h-[calc(100%-1rem)] flex flex-col bg-slate-100/80 dark:bg-slate-800/80 border border-slate-200/50 dark:border-slate-600/60 shadow-float px-3 pt-1.5 pb-2.5 md:px-3 md:pt-1.5 md:pb-2.5 rounded-2xl backdrop-blur-md transition-transform duration-200 ease-out"
  end

  defp top_chrome_outer_classes(:map) do
    "fixed right-2 top-2 z-50"
  end

  defp top_chrome_outer_classes(_) do
    "fixed inset-x-0 top-0 z-50 bg-slate-50/95 py-2 backdrop-blur-md after:pointer-events-none after:absolute after:inset-x-0 after:top-full after:h-8 after:bg-gradient-to-b after:from-slate-50/85 after:to-transparent after:backdrop-blur-[2px] dark:bg-slate-900/95 dark:after:from-slate-900/85 #{app_shell_horizontal_padding()}"
  end

  defp top_chrome_inner_classes(:map) do
    "flex items-center gap-2.5"
  end

  defp top_chrome_inner_classes(_) do
    "mx-auto flex w-full max-w-[1600px] min-w-0 items-center gap-3"
  end

  defp main_wrapper_classes(:map), do: ""

  defp main_wrapper_classes(_),
    do: "#{app_shell_horizontal_padding()} pb-10 pt-[5.5rem]"

  defp app_shell_horizontal_padding do
    "px-6 sm:px-10 md:px-14 lg:px-20 xl:px-24 2xl:px-32"
  end

  defp main_content_classes(:map), do: "relative min-h-screen"
  defp main_content_classes(_), do: "mx-auto w-full max-w-[1600px]"

  defp signed_in?(%{user: %{}}), do: true
  defp signed_in?(_), do: false

  defp display_name_or_email(%{display_name: name, email: email}) do
    case to_string(name || "") |> String.trim() do
      "" -> email
      value -> value
    end
  end

  defp display_name_or_email(%{email: email}), do: email
  defp display_name_or_email(_), do: nil

  defp dashboard_sidebar_items(scope) do
    is_admin? = !!(scope && scope.is_admin)

    [
      %{
        label: "Dados",
        path: ~p"/dashboard/data-points",
        icon: "hero-chart-bar",
        description: "Acesso a séries e exportação",
        requires_auth: true,
        requires_admin: false
      },
      %{
        label: "Relatório",
        path: ~p"/dashboard/storage-report",
        icon: "hero-chart-bar",
        description: "Armazenamento por bacia e barragem",
        children: [
          %{label: "Semanal", path: ~p"/dashboard/storage-report"},
          %{label: "Evolução", path: ~p"/dashboard/overview"}
        ],
        requires_auth: true,
        requires_admin: false
      },
      %{
        label: "Notificações",
        path: ~p"/dashboard/notifications",
        icon: "hero-bell-alert",
        description: "Monitorização de risco",
        requires_auth: true,
        requires_admin: false
      },
      %{
        label: "API",
        path: ~p"/dashboard/api-tokens",
        icon: "hero-key",
        description: "Acesso e documentação da API",
        children: [
          %{label: "Acesso", path: ~p"/dashboard/api-tokens"},
          %{label: "Documentação", path: ~p"/dashboard/api-docs"}
        ],
        requires_auth: true,
        requires_admin: false
      },
      %{
        label: "Admin",
        path: ~p"/dashboard/admin",
        icon: "hero-lock-closed",
        description: "Visão global de utilização e risco",
        requires_auth: true,
        requires_admin: true
      }
    ]
    |> Enum.filter(fn item -> !item.requires_admin || is_admin? end)
  end
end
