defmodule BarragensptWeb.BasinDetailLive do
  use BarragensptWeb, :live_view
  import Ecto.Query
  alias Barragenspt.Mappers.Colors
  alias Barragenspt.Hydrometrics.Stats
  alias Barragenspt.Geo.Coordinates

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

    lines = [%{k: "Observado", v: Colors.lookup(id)}] ++ [%{k: "Média", v: "grey"}]

    query = from p in Barragenspt.Hydrometrics.Dam, where: p.basin_id == ^id

    dams = Barragenspt.Repo.all(query)

    bounding_box_for_basin =
      dams
      |> Enum.map(fn dam -> Coordinates.from_dam(dam) end)
      |> Enum.map(fn %{lat: lat, lon: lon} -> [lon, lat] end)
      |> Geocalc.bounding_box_for_points()

    socket =
      socket
      |> assign(basin_id: id)
      |> assign(dams: enrich_dams(dams), basin: Enum.at(dams, 0).basin)
      |> push_event("update_chart", %{data: data, lines: lines})
      |> push_event("zoom_map", %{bounding_box: bounding_box_for_basin})

    {:noreply, socket}
  end

  defp enrich_dams(dams) do
    site_ids = Enum.map(dams, & &1.site_id)

    query =
      from(b in Barragenspt.Hydrometrics.DailyAverageStorageBySite,
        where: b.period == ^"#{Timex.now().day}-#{Timex.now().month}" and b.site_id in ^site_ids
      )

    historic_values = Barragenspt.Repo.all(query)

    dams
    |> Enum.map(fn dam ->
      dam.site_id
      |> Stats.current_level_for_dam()
      |> then(fn {value} -> value end)
      |> Decimal.round(1)
      |> Decimal.to_float()
      |> then(fn value -> Map.put(dam, :pct, value) end)
    end)
    |> Enum.map(fn dam ->
      case Enum.find(historic_values, fn hv -> hv.site_id == dam.site_id end) do
        nil ->
          Map.put(dam, :average_historic_value, "-")

        hv ->
          rounded_value = hv.value |> Decimal.round(1) |> Decimal.to_float()

          Map.put(dam, :average_historic_value, rounded_value)
      end
    end)
    |> Enum.map(fn dam ->
      Map.put(dam, :capacity_color, Colors.lookup_capacity(dam.pct))
    end)
  end
end
