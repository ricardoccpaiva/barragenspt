defmodule DamDetailComponent do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div id="mySidenavDam" class={@class}>
    <div class="is-pulled-right">
    <button class="card-header-icon" aria-label="more options">
      <span class="icon">
        <%= live_patch "" , to: "/?basin_id=#{@dam.basin_id}", class: "fa fa-xmark" %>
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
      <span class="is-size-7 has-text-weight-bold">Armazenamento a <%= @last_data_point %>: <%= @current_capacity %>%</span>
      <br/>
      <span class="is-size-7 has-text-weight-bold">Cota a <%= @last_elevation_date %>: <%= @last_elevation %>m</span>
      <i id="show_last_updated_at_info_btn" style="cursor: pointer" class="fa-solid fa-circle-info"></i>
      <div class="control" style="margin-top: 5px;">
        <progress class="progress is-link is-small" value={@current_capacity} max="100"></progress>
      </div>
      <div id="last_updated_at_info" class="notification is-info is-light" style="padding: 1rem 2rem 1rem 1rem; margin-top: 10px; line-height: 1em; display: none;">
        <button id="hide_last_updated_at_info_btn" class="delete"></button>
        <span class="is-size-7 has-text-weight-bold">
          Atualizamos o barragens.pt pelo menos 1 vez por dia. No entanto, para algumas barragens, os dados oficiais podem ter até 1 semana de atraso.
        </span>
      </div>
    </div>

    <div class="field" style="margin-top: 10px;">
      <span class="is-size-7 has-text-weight-bold">Tipos de utilização</span>
      <div class="control" style="margin-top: 5px;">
      <%= for ut <- @dam_usage_types do %>

    <span class="tag is-link is-light"><%= ut %></span>
    <% end %>
      </div>
    </div>

    <div class="field">
      <span class="is-size-7 has-text-weight-bold">Evolução temporal</span>
      <div class="control">
        <div style="text-align:right;">
          <div class="select is-small" style="margin-top:-25px; margin-bottom: 10px;">
            <select id="ctw_d" phx-hook="DamChartTimeWindow">
              <option value="s1">1 semana</option>
              <option value="s2">2 semanas</option>
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
    <script type="text/javascript">
      document.getElementById('show_last_updated_at_info_btn').addEventListener("click", e => {
        document.getElementById("last_updated_at_info").style.display = 'block';
      });

      document.getElementById('hide_last_updated_at_info_btn').addEventListener("click", e => {
        document.getElementById("last_updated_at_info").style.display = 'none';
      });
    </script>
    </div>
    """
  end
end
