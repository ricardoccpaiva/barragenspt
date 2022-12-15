defmodule BarragensptWeb.BasinDetailLive do
  use BarragensptWeb, :live_view
  alias Barragenspt.Mappers.Colors
  alias Barragenspt.Hydrometrics.{Dams, Basins}

  def handle_event("change_window", %{"value" => value}, socket) do
    usage_types = Map.get(socket.assigns, :selected_usage_types, [])

    id = socket.assigns.basin_id

    %{current_storage: current_storage} = Basins.get_storage(id)

    data =
      case value do
        "y" <> val ->
          {int_value, ""} = Integer.parse(val)
          Basins.monthly_stats_for_basin(id, usage_types, int_value)

        "m" <> val ->
          {int_value, ""} = Integer.parse(val)
          Basins.daily_stats_for_basin(id, usage_types, int_value)
      end

    lines =
      [%{k: "Observado", v: Colors.lookup_capacity(current_storage)}] ++
        [%{k: "Média", v: "grey"}]

    socket = push_event(socket, "update_chart", %{data: data, lines: lines})

    {:noreply, socket}
  end

  def handle_params(%{"id" => id}, _url, socket) do
    usage_types = Map.get(socket.assigns, :selected_usage_types, [])

    stats = Basins.monthly_stats_for_basin(id, usage_types)
    bounding_box = Dams.bounding_box(id)
    basin_summary = get_basin_summary(id, usage_types)

    %{name: basin_name, current_storage: current_storage} = Basins.get_storage(id)

    chart_lines = [
      %{k: "Observado", v: Colors.lookup_capacity(current_storage)},
      %{k: "Média", v: "grey"}
    ]

    socket =
      socket
      |> assign(basin_id: id)
      |> assign(basin_summary: basin_summary, basin: basin_name)
      |> push_event("update_chart", %{data: stats, lines: chart_lines})
      |> push_event("zoom_map", %{basin_id: id, bounding_box: bounding_box})
      |> push_event("enable_tabs", %{})

    {:noreply, socket}
  end

  defp get_basin_summary(id, usage_types) do
    id
    |> Basins.summary_stats(usage_types)
    |> Enum.map(fn %{current_storage: current_storage} = m ->
      Map.put(
        m,
        :capacity_color,
        current_storage |> Decimal.round(1) |> Decimal.to_float() |> Colors.lookup_capacity()
      )
    end)
  end
end
