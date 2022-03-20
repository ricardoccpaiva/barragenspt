defmodule BarragensptWeb.BasinDetailLive do
  use BarragensptWeb, :live_view
  alias Barragenspt.Mappers.Colors
  alias Barragenspt.Hydrometrics.{Dams, Basins}

  def handle_event("change_window", %{"value" => value}, socket) do
    id = socket.assigns.basin_id

    data =
      case value do
        "y" <> val ->
          {int_value, ""} = Integer.parse(val)
          Basins.monthly_stats_for_basin(id, int_value)

        "m" <> val ->
          {int_value, ""} = Integer.parse(val)
          Basins.daily_stats_for_basin(id, int_value)
      end

    lines = [%{k: "Observado", v: Colors.lookup(id)}] ++ [%{k: "Média", v: "grey"}]

    socket = push_event(socket, "update_chart", %{data: data, lines: lines})

    {:noreply, socket}
  end

  def handle_params(%{"id" => id}, _url, socket) do
    stats = Basins.monthly_stats_for_basin(id)
    bounding_box = Dams.bounding_box(id)
    basin_summary = get_basin_summary(id)

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
      |> push_event("zoom_map", %{bounding_box: bounding_box})
      |> push_event("enable_tabs", %{})

    {:noreply, socket}
  end

  defp get_basin_summary(id) do
    id
    |> Basins.summary_stats()
    |> Enum.map(fn %{current_storage: current_storage} = m ->
      Map.put(
        m,
        :capacity_color,
        current_storage |> Decimal.to_float() |> Colors.lookup_capacity()
      )
    end)
  end
end
