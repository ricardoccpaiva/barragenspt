defmodule SpainBasinDetailComponent do
  use Phoenix.LiveComponent
  alias BarragensptWeb.Router.Helpers, as: Routes

  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id="mySidenavBasin" class={@class}>
    <div class="is-pulled-right">
    <button class="card-header-icon" aria-label="more options">
      <span class="icon">
        <%= live_patch "" , to: Routes.homepage_path(@socket, :index), class: "fa fa-xmark" %>
      </span>
    </button>
    </div>
    <div class="card-content">
    <h6 class="is-6">
      <b>Bacia: </b>
      <%= @basin %>
    </h6>
    <div class="field" style="margin-top: 10px;">
      <span class="is-size-7 has-text-weight-bold">Armazenamento atual: <%= @current_pct %>%</span>
      <div class="control" style="margin-top: 5px;">
        <progress class="progress is-link is-small" value={@current_pct} max="100"></progress>
      </div>
    </div>
        </div>
    </div>
    """
  end
end
