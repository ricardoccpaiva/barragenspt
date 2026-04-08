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
      |> assign(:dashboard_sidebar_items, dashboard_sidebar_items())

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
          class="fixed left-2 top-2 z-50 inline-flex h-10 w-10 items-center justify-center rounded-xl bg-white/90 text-slate-700 shadow-card dark:bg-slate-800/90 dark:text-slate-200 md:hidden"
          onclick="window.toggleAppShellSidebar && window.toggleAppShellSidebar(true)"
          aria-label="Abrir navegação"
        >
          <.icon name="hero-bars-3" class="h-5 w-5" />
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

          <div class="flex-1 min-h-0 overflow-y-auto pt-2">
            <%= if @sidebar != [] do %>
              {render_slot(@sidebar)}
            <% end %>
          </div>
        </aside>
      <% end %>

      <div class={top_chrome_wrapper_classes(@mode)}>
        <%= if @mode != :map and @signed_in? do %>
          <div class="flex min-w-0 shrink-0 items-center gap-2">
            <div
              id="dashboard-app-nav"
              phx-hook="NavRouteActive"
              class="inline-flex min-h-10 max-w-[calc(100vw-10rem)] flex-nowrap items-center gap-0.5 overflow-x-auto rounded-xl border border-slate-200 bg-white/90 p-1 shadow-card [-ms-overflow-style:none] [scrollbar-width:none] dark:border-slate-600 dark:bg-slate-800/90 [&::-webkit-scrollbar]:hidden"
            >
              <%= for item <- @dashboard_sidebar_items do %>
                <.link
                  navigate={item.path}
                  data-nav-path={item.path}
                  class="inline-flex h-8 shrink-0 items-center gap-1 rounded-lg px-2.5 text-sm font-semibold leading-none text-slate-500 hover:bg-slate-100/90 dark:text-slate-400 dark:hover:bg-slate-700/60"
                >
                  <.icon name={item.icon} class="h-3.5 w-3.5 shrink-0 opacity-80" />
                  {item.label}
                </.link>
              <% end %>
            </div>
            <.live_component
              module={BarragensptWeb.EvaluateAlertsShortcutComponent}
              id="dashboard-evaluate-alerts-top"
            />
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
            <% else %>
              <.link
                href={~p"/dashboard"}
                data-nav-path={~p"/dashboard"}
                class="inline-flex h-8 items-center rounded-lg px-3 text-sm font-semibold leading-none text-slate-500 transition-colors hover:bg-slate-100/90 dark:text-slate-400 dark:hover:bg-slate-700/60"
              >
                Dashboard
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
              aria-label={if(@signed_in?, do: "Menu da conta", else: "Conta — iniciar sessão ou registo")}
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
                    {case @current_scope.user.email do
                      e when is_binary(e) and e != "" -> e |> String.first() |> String.upcase()
                      _ -> "U"
                    end}
                  </span>
                <% end %>
              <% else %>
                <.icon name="hero-user-circle" class="h-8 w-8 shrink-0 text-slate-500 dark:text-slate-400" />
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

      <div class={main_wrapper_classes(@mode)}>
        <main class={main_content_classes(@mode)}>
          <.flash_group flash={@flash} />
          {render_slot(@inner_block)}
        </main>
      </div>

      <.beta_corner_notice />
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
    "fixed z-40 w-[80%] max-w-[279px] -translate-x-full md:translate-x-0 md:max-w-none md:w-[317px] inset-2 h-[calc(100%-1rem)] flex flex-col bg-slate-100/80 dark:bg-slate-800/80 border border-slate-200/50 dark:border-slate-600/60 shadow-float px-3 pt-1.5 pb-2.5 md:px-3 md:pt-1.5 md:pb-2.5 rounded-2xl backdrop-blur-md transition-transform duration-200 ease-out"
  end

  defp top_chrome_wrapper_classes(:map) do
    "fixed right-2 top-2 z-50 flex items-center gap-2.5"
  end

  defp top_chrome_wrapper_classes(_) do
    # Same horizontal inset as main; w-full + ml-auto on the right cluster keeps utilities flush to the content edge.
    "fixed inset-x-0 top-2 z-50 flex w-full min-w-0 items-center gap-3 #{app_shell_horizontal_padding()}"
  end

  defp main_wrapper_classes(:map), do: ""

  defp main_wrapper_classes(_),
    do: "#{app_shell_horizontal_padding()} pb-10 pt-[5.5rem]"

  defp app_shell_horizontal_padding do
    "px-6 sm:px-10 md:px-14 lg:px-20 xl:px-24 2xl:px-32"
  end

  defp main_content_classes(:map), do: "relative min-h-screen"
  defp main_content_classes(_), do: "w-full max-w-none"

  defp signed_in?(%{user: %{}}), do: true
  defp signed_in?(_), do: false

  defp dashboard_sidebar_items do
    [
      %{
        label: "Dados",
        path: ~p"/dashboard/data-points",
        icon: "hero-chart-bar",
        description: "Acesso a séries e exportação",
        requires_auth: true
      },
      %{
        label: "Relatório IA",
        path: ~p"/dashboard/basin-report",
        icon: "hero-sparkles",
        description: "Análises automáticas por bacia",
        requires_auth: true
      },
      %{
        label: "Alertas",
        path: ~p"/dashboard/alerts",
        icon: "hero-bell-alert",
        description: "Monitorização de risco",
        requires_auth: true
      }
    ]
  end
end
