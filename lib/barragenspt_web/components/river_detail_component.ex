defmodule RiverDetailComponent do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div id="mySidenavBasin" class={@class}>
    <div class="is-pulled-right">
    <button class="card-header-icon" aria-label="more options">
      <span class="icon">
        <%= live_patch "" , to: "/", class: "fa fa-xmark" %>
      </span>
    </button>
    </div>
    <div class="card-content">
    <h6 class="is-6">
      <b>Rio: </b>
      <%= @river %>
    </h6>
    <div id="tabs-with-content" style="margin-top: 10px">
      <table class="table is-fullwidth">
        <thead>
          <tr>
            <th>Albufeira</th>
            <th>% Atual</th>
            <th>% Média</th>
          </tr>
        </thead>
        <tbody>
          <%= for %{site_id: id, site_name: name, current_storage: current_storage, average_storage:
            average_storage, capacity_color: capacity_color} <- @basin_summary do %>
            <tr id={"row_#{id}"} class="row">
              <td style="padding-right: 30px">
                <%= live_patch to: "/?dam_id=#{id}", replace: true do %>
                  <%= name %>
                <% end %>
              </td>
              <td class="has-text-centered"><span class="tag is-light" style={"background-color:#{capacity_color}"}>
                <%= current_storage %>%
                  </span>
              </td>
              <td class="has-text-centered"><span class="tag is-light">
                <%= average_storage %>%
                </span>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>

    </div>
    </div>
    """
  end
end
