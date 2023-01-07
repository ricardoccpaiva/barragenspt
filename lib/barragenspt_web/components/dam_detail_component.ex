defmodule DamDetailComponent do
  use Phoenix.LiveComponent
  alias BarragensptWeb.Router.Helpers, as: Routes

  def render(assigns) do
    ~H"""
    <div id="mySidenavDam" class={@class}>
    <div class="is-pulled-right">
    <button class="card-header-icon" aria-label="more options">
      <span class="icon">
        <%= live_patch "" , to: Routes.homepage_path(@socket, :index, %{"basin_id" => @dam.basin_id}), class: "fa fa-xmark" %>
      </span>
    </button>
    </div>
    <div class="card-content">
    <h6 class="is-6">
      <b>Bacia: </b>
      <%= @dam.basin %>
    </h6>
    <h6 class="is-6">
      <b>Albufeira: </b>
      <%= @dam.name %>
    </h6>

    <div class="field" style="margin-top: 10px;">
      <span class="is-size-7 has-text-weight-bold">Tipos de utilização</span>
      <div class="control" style="margin-top: 5px;">
      <%= for ut <- @dam_usage_types do %>

    <span class="tag is-link is-light"><%= ut %></span>
    <% end %>
      </div>
    </div>

    <div class="field" style="margin-top: 10px;">
      <span class="is-size-7 has-text-weight-bold">Armazenamento atual: <%= @current_capacity %>%</span>
      <div class="control" style="margin-top: 5px;">
        <progress class="progress is-link is-small" value={@current_capacity} max="100"></progress>
      </div>
    </div>
    <div class="field">
      <span class="is-size-7 has-text-weight-bold">Evolução temporal</span>
      <div class="control">
        <div style="text-align:right;">
          <div class="select is-small" style="margin-top:15px; margin-bottom: 10px;">
            <select id="ctw_d" phx-hook="DamChartTimeWindow">
              <option value="m2">1 mês</option>
              <option value="m6">6 meses</option>
              <option value="y2" selected>2 anos</option>
              <option value="y5">5 anos</option>
              <option value="y10">10 anos</option>
              <option value="y50">Sem limite</option>
            </select>
          </div>
        </div>
        <div id="dam_chart_evo" phx-update="ignore"></div>
      </div>
    </div>


    <div class="content">
      <%= for key <- Map.keys(@dam.metadata) do %>
        <h6 class="is-6">
          <%= key %>
        </h6>
        <div style="margin-left: 10px; margin-bottom: 10px;">
          <%= for {k, v} <- @dam.metadata[key] do %>

            <span class="is-size-7 has-text-weight-bold">
              <%= k |> String.trim("\"") %>:
            </span>
            <span class="is-size-7">
              <%= v |> String.trim(",") |> String.trim("\"") |> String.capitalize() %>
            </span>
            <br />
            <% end %>
        </div>
        <% end %>
    </div>

    </div>
    </div>
    """
  end
end