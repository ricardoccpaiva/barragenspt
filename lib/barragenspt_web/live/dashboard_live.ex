defmodule BarragensptWeb.DashboardLive do
  use BarragensptWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <%!-- Hero (+ compact login card for guests) --%>
      <%= if @signed_in? do %>
        <div class="mb-10">
          <p class="text-xs font-semibold uppercase tracking-widest text-brand-500 dark:text-brand-400">
            barragens.pt · Dashboard
          </p>
          <h1 class="mt-2 text-3xl font-bold tracking-tight text-slate-900 dark:text-slate-50 sm:text-4xl">
            Bem-vindo, <span class="text-brand-600 dark:text-brand-400">{String.split(@current_scope.user.email, "@") |> List.first()}</span>.
          </h1>
          <p class="mt-3 max-w-xl text-base text-slate-500 dark:text-slate-400">
            Analisa dados hidrométricos, gera relatórios com IA e monitoriza albufeiras portuguesas com alertas personalizados.
          </p>
        </div>
      <% else %>
        <div class="mb-10 flex flex-col gap-5 lg:flex-row lg:items-start lg:justify-between lg:gap-8">
          <div class="min-w-0 flex-1">
            <p class="text-xs font-semibold uppercase tracking-widest text-brand-500 dark:text-brand-400">
              barragens.pt · Dashboard
            </p>
            <h1 class="mt-2 text-3xl font-bold tracking-tight text-slate-900 dark:text-slate-50 sm:text-4xl">
              O teu centro de análise hidrométrica
            </h1>
            <p class="mt-3 max-w-xl text-base text-slate-500 dark:text-slate-400">
              Analisa dados hidrométricos, gera relatórios com IA e monitoriza albufeiras portuguesas com alertas personalizados.
            </p>
          </div>
          <div class="w-full shrink-0 rounded-xl border border-brand-200/90 bg-gradient-to-br from-brand-50/95 to-sky-50/80 p-3.5 shadow-sm dark:border-brand-800/60 dark:from-brand-950/50 dark:to-slate-900/80 dark:shadow-none lg:max-w-[min(100%,20rem)] lg:self-start xl:max-w-[22rem]">
            <p class="text-xs font-semibold text-brand-900 dark:text-brand-100">
              Conta gratuita · Google ou e-mail
            </p>
            <p class="mt-1.5 text-xs leading-snug text-slate-600 dark:text-slate-400">
              Inicia sessão para dados, relatórios IA e alertas.
            </p>
            <div class="mt-3 flex flex-col gap-2">
              <.link
                navigate={~p"/users/log-in"}
                class="inline-flex w-full items-center justify-center rounded-lg bg-brand-600 px-3 py-1.5 text-xs font-semibold text-white shadow-sm transition-colors hover:bg-brand-700 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:ring-offset-1 dark:focus:ring-offset-slate-900"
              >
                Iniciar sessão
              </.link>
              <.link
                navigate={~p"/users/register"}
                class="inline-flex w-full items-center justify-center rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs font-semibold text-slate-800 shadow-sm transition-colors hover:bg-slate-50 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100 dark:hover:bg-slate-700"
              >
                Criar conta
              </.link>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Feature cards --%>
      <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 xl:grid-cols-4">
        <%!-- Relatório IA --%>
        <.link
          {dashboard_link_attrs(@current_scope, ~p"/dashboard/basin-report")}
          class="group relative flex flex-col overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm transition-all hover:border-brand-300 hover:shadow-md dark:border-slate-700 dark:bg-slate-800 dark:hover:border-brand-600/60"
        >
          <div class="flex items-start gap-4 p-6">
            <span class="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-brand-50 text-brand-600 ring-1 ring-brand-100 dark:bg-brand-950/50 dark:text-brand-400 dark:ring-brand-800/60">
              <svg class="size-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="1.75"
                  d="M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09ZM18.259 8.715 18 9.75l-.259-1.035a3.375 3.375 0 0 0-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 0 0 2.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 0 0 2.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 0 0-2.456 2.456Z"
                />
              </svg>
            </span>
            <div class="min-w-0">
              <p class="text-sm font-semibold text-slate-900 dark:text-slate-100">Relatório IA</p>
              <p class="mt-1 text-sm leading-relaxed text-slate-500 dark:text-slate-400">
                Gera relatórios em linguagem natural para qualquer bacia hidrográfica — ou para todas em simultâneo — com análise de armazenamento, caudais e comparações temporais, em segundos.
              </p>
            </div>
          </div>
        </.link>

        <%!-- Dados --%>
        <.link
          {dashboard_link_attrs(@current_scope, ~p"/dashboard/data-points")}
          class="group relative flex flex-col overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm transition-all hover:border-teal-300 hover:shadow-md dark:border-slate-700 dark:bg-slate-800 dark:hover:border-teal-600/60"
        >
          <div class="flex items-start gap-4 p-6">
            <span class="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-teal-50 text-teal-600 ring-1 ring-teal-100 dark:bg-teal-950/40 dark:text-teal-400 dark:ring-teal-800/60">
              <svg class="size-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="1.75"
                  d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 0 1 3 19.875v-6.75ZM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 0 1-1.125-1.125V8.625ZM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 0 1-1.125-1.125V4.125Z"
                />
              </svg>
            </span>
            <div class="min-w-0">
              <p class="text-sm font-semibold text-slate-900 dark:text-slate-100">
                Dados Hidrométricos
              </p>
              <p class="mt-1 text-sm leading-relaxed text-slate-500 dark:text-slate-400">
                Explora a série histórica de medições de volume, caudal e outros parâmetros, filtrando por barragem, bacia, parâmetro e intervalo de datas. Exporta em CSV.
              </p>
            </div>
          </div>
        </.link>

        <%!-- Alertas --%>
        <.link
          {dashboard_link_attrs(@current_scope, ~p"/dashboard/alerts")}
          class="group relative flex flex-col overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm transition-all hover:border-amber-300 hover:shadow-md dark:border-slate-700 dark:bg-slate-800 dark:hover:border-amber-600/60"
        >
          <div class="flex items-start gap-4 p-6">
            <span class="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-amber-50 text-amber-600 ring-1 ring-amber-100 dark:bg-amber-950/40 dark:text-amber-400 dark:ring-amber-800/60">
              <svg class="size-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="1.75"
                  d="M14.857 17.082a23.848 23.848 0 0 0 5.454-1.31A8.967 8.967 0 0 1 18 9.75V9A6 6 0 0 0 6 9v.75a8.967 8.967 0 0 1-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 0 1-5.714 0m5.714 0a3 3 0 1 1-5.714 0"
                />
              </svg>
            </span>
            <div class="min-w-0">
              <p class="text-sm font-semibold text-slate-900 dark:text-slate-100">Alertas</p>
              <p class="mt-1 text-sm leading-relaxed text-slate-500 dark:text-slate-400">
                Define limiares de armazenamento ou caudal por albufeira e recebe notificações por e-mail quando os valores ultrapassam ou descem abaixo dos teus critérios.
              </p>
            </div>
          </div>
        </.link>

        <%!-- Tokens API --%>
        <.link
          {dashboard_link_attrs(@current_scope, ~p"/dashboard/api-tokens")}
          class="group relative flex flex-col overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm transition-all hover:border-violet-300 hover:shadow-md dark:border-slate-700 dark:bg-slate-800 dark:hover:border-violet-600/60"
        >
          <div class="flex items-start gap-4 p-6">
            <span class="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-violet-50 text-violet-600 ring-1 ring-violet-100 dark:bg-violet-950/40 dark:text-violet-400 dark:ring-violet-800/60">
              <.icon name="hero-key" class="size-5" />
            </span>
            <div class="min-w-0">
              <p class="text-sm font-semibold text-slate-900 dark:text-slate-100">Tokens API</p>
              <p class="mt-1 text-sm leading-relaxed text-slate-500 dark:text-slate-400">
                Gere até cinco tokens com scopes (barragens, bacias, pontos de dados), revogue quando não precisares e consulta o histórico de criação e revogação.
              </p>
            </div>
          </div>
        </.link>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    signed_in? = socket.assigns.current_scope.user != nil
    {:ok, assign(socket, :signed_in?, signed_in?)}
  end

  defp dashboard_link_attrs(%{user: user}, path) when not is_nil(user), do: [navigate: path]
  defp dashboard_link_attrs(_scope, path), do: [href: path]
end
