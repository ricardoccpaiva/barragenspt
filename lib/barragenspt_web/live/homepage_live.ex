defmodule BarragensptWeb.HomepageLive do
  use BarragensptWeb, :live_view

  alias Barragenspt.Mappers.Colors
  alias Barragenspt.Hydrometrics.Basins

  def mount(_, _, socket) do
    basins_summary = get_data()
    all_basins = Basins.all()
    data_to_feed = Basins.monthly_stats_for_basins()

    lines =
      Enum.map(all_basins, fn %{id: id, name: basin_name} ->
        %{k: basin_name, v: Colors.lookup(id)}
      end)

    socket =
      socket
      |> assign(basins_summary: basins_summary)
      |> push_event("update_chart", %{data: data_to_feed, lines: lines})
      |> push_event("zoom_map", %{})
      |> push_event("enable_tabs", %{})

    {:ok, socket}
  end

  defp get_data() do
    Enum.map(Basins.summary_stats(), fn {basin_id, name, current_storage, value} ->
      %{
        id: basin_id,
        name: name,
        current_storage: current_storage,
        average_historic_value: value,
        capacity_color: current_storage |> Decimal.to_float() |> Colors.lookup_capacity()
      }
    end)
  end
end
