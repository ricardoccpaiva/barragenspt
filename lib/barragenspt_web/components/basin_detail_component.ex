defmodule BasinDetailComponent do
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
      <b>Bacia: </b>
      <%= @basin %>
    </h6>
    <div id="tabs-with-content" style="margin-top: 10px">
      <div class="tabs is-small">
        <ul>
          <li class="is-active">
            <a>
              <span class="icon is-small"><i class="fa-solid fa-table-list" aria-hidden="true"></i></span>
              <span>Dados atuais</span>
            </a>
          </li>
          <li>
            <a onclick="document.getElementById('ctw_b').click();">
              <span class="icon is-small"><i class="fa-solid fa-chart-line" aria-hidden="true"></i></span>
              <span>Dados históricos</span>
            </a>
          </li>
        </ul>
      </div>
      <div>
        <section class="tab-content">
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
                    </span></td>
                  <td class="has-text-centered"><span class="tag is-light">
                      <%= average_storage %>%
                    </span></td>
                </tr>
                <% end %>
            </tbody>
          </table>
        </section>
        <section class="tab-content">
          <div style="text-align:right;">
            <div class="select is-small" style="margin-top:15px; margin-bottom: 10px;">
              <select id="ctw_b" phx-hook="BasinChartTimeWindow">
                <option value="m1">1 mês</option>
                <option value="m2">2 meses</option>
                <option value="m6">6 meses</option>
                <option value="y2" selected>2 anos</option>
                <option value="y5">5 anos</option>
                <option value="y10">10 anos</option>
                <option value="y50">Sem limite</option>
              </select>
            </div>
          </div>
          <div style="width:335px; height: 230px" id="graph_ot" phx-hook="MetricsEvolution"/>
        </section>
      </div>
    </div>

    </div>
    </div>
    """
  end
end
