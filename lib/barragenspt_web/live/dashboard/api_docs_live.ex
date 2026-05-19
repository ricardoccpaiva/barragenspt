defmodule BarragensptWeb.Dashboard.ApiDocsLive do
  @moduledoc false
  use BarragensptWeb, :live_view

  on_mount {BarragensptWeb.UserAuth, :require_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    redoc_src = url(~p"/api/redoc")

    {:ok,
     socket
     |> assign(:page_title, "Documentação API")
     |> assign(:redoc_src, redoc_src)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex min-h-0 flex-1 flex-col gap-4">
        <div
          class="min-h-0 flex-1 overflow-hidden rounded-2xl border border-slate-200/90 bg-white shadow-[0_4px_24px_-6px_rgba(15,23,42,0.12)] ring-1 ring-slate-950/[0.04] dark:border-slate-700/90 dark:bg-slate-900/45 dark:ring-white/[0.06]"
          phx-update="ignore"
          id="api-redoc-embed"
        >
          <iframe
            src={@redoc_src}
            title="Documentação OpenAPI — ReDoc"
            class="h-[min(78vh,52rem)] w-full border-0"
            loading="lazy"
          />
        </div>
      </div>
    </Layouts.app>
    """
  end
end
