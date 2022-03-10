defmodule BarragensptWeb.HomepageLive do
  use BarragensptWeb, :live_view

  alias Barragenspt.Mappers.Colors
  alias Barragenspt.Hydrometrics.Basins
  alias Barragenspt.Hydrometrics.Basin
  alias Barragenspt.Hydrometrics.Stats

  def mount(_params, _session, socket) do
    basins_summary =
      Enum.map(Stats.basins_summary(), fn {basin_id, name, current_storage, value} ->
        %{
          id: basin_id,
          name: name,
          current_storage: current_storage,
          average_historic_value: value,
          capacity_color: current_storage |> Decimal.to_float() |> Colors.lookup_capacity()
        }
      end)

    {:ok, assign(socket, basins_summary: basins_summary)}
  end

  def handle_params(_params, _url, socket) do
    all_basins = Basin.all()
    data_to_feed = Basins.monthly_stats_for_basins()

    lines =
      Enum.map(all_basins, fn %{id: id, name: basin_name} ->
        %{k: basin_name, v: Colors.lookup(id)}
      end)

    socket =
      socket
      |> push_event("update_chart", %{data: data_to_feed, lines: lines})
      |> push_event("zoom_map", %{})

    {:noreply, socket}
  end
end
