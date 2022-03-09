defmodule BarragensptWeb.BasinDetailLive do
  use BarragensptWeb, :live_view
  alias Barragenspt.Mappers.Colors
  alias Barragenspt.Hydrometrics.Stats
  alias BarragensPt.Hydrometrics.Dams

  def handle_event("change_window", %{"value" => value}, socket) do
    id = socket.assigns.basin_id
    {int_value, ""} = Integer.parse(value)
    data = Stats.for_basin(id, int_value)

    lines = [%{k: "Observado", v: Colors.lookup(id)}] ++ [%{k: "Média", v: "grey"}]

    socket = push_event(socket, "update_chart", %{data: data, lines: lines})

    {:noreply, socket}
  end

  def handle_params(%{"id" => id}, _url, socket) do
    data = Stats.for_basin(id)

    bounding_box = Dams.bounding_box(id)

    stats_summary = Stats.basin_summary(id)
    %{basin_name: basin_name} = Enum.at(stats_summary, 0)

    current_basin_storage =
      Enum.reduce(stats_summary, 0, fn ss, acc -> Decimal.to_float(ss.current_storage) + acc end) /
        Enum.count(stats_summary)

    lines = [
      %{k: "Observado", v: Colors.lookup_capacity(current_basin_storage)},
      %{k: "Média", v: "grey"}
    ]

    basin_summary =
      Enum.map(stats_summary, fn %{current_storage: current_storage} = m ->
        Map.put(
          m,
          :capacity_color,
          current_storage |> Decimal.to_float() |> Colors.lookup_capacity()
        )
      end)

    socket =
      socket
      |> assign(basin_id: id)
      |> assign(basin_summary: basin_summary, basin: basin_name)
      |> push_event("update_chart", %{data: data, lines: lines})
      |> push_event("zoom_map", %{bounding_box: bounding_box})

    {:noreply, socket}
  end
end
