defmodule BarragensptWeb.BasinDetailLive do
  use BarragensptWeb, :live_view
  import Ecto.Query
  alias Barragenspt.Mappers.Colors
  alias Barragenspt.Hydrometrics.Basins
  alias Barragenspt.Hydrometrics.Stats
  alias Barragenspt.Geo.Coordinates

  def handle_params(%{"id" => id}, _url, socket) do
    {parsed_id, ""} = Integer.parse(id)
    %{basin: basin_name} = basin = Basins.get(parsed_id)

    data = Stats.for_basin(basin)

    lines = [%{k: basin_name, v: Colors.lookup(id)}]

    query = from p in Barragenspt.Hydrometrics.Dam, where: p.basin_id == ^String.to_integer(id)

    dams = Barragenspt.Repo.all(query)

    bounding_box_for_basin =
      dams
      |> Enum.map(fn dam -> Coordinates.from_dam(dam) end)
      |> Enum.map(fn %{lat: lat, lon: lon} -> [lon, lat] end)
      |> Geocalc.bounding_box_for_points()

    socket =
      socket
      |> assign(dams: enrich_dams(dams), basin: basin.basin)
      |> push_event("update_chart", %{data: data, lines: lines})
      |> push_event("zoom_map", %{bounding_box: bounding_box_for_basin})

    {:noreply, socket}
  end

  defp enrich_dams(dams) do
    dams
    |> Enum.map(fn dam ->
      {pct} = Stats.current_level_for_dam(dam.site_id)
      Map.put(dam, :pct, pct)
    end)
    |> Enum.map(fn dam ->
      {pct} = Stats.historical_level_for_dam(dam.site_id)
      Map.put(dam, :pct_2, pct)
    end)
    |> Enum.map(fn dam ->
      Map.put(dam, :capacity_color, Colors.lookup_capacity(dam.pct))
    end)
  end
end
