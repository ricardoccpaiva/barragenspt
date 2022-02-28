defmodule BarragensptWeb.BasinDetailLive do
  use BarragensptWeb, :live_view
  import Ecto.Query
  alias Barragenspt.Mappers.Colors
  alias Barragenspt.Hydrometrics.Basins
  alias Barragenspt.Hydrometrics.Stats

  def mount(%{"id" => id}, _session, socket) do
    basin = Basins.get(id)

    query = from p in Barragenspt.Hydrometrics.Dam, where: p.basin_id == ^String.to_integer(id)

    dams =
      query
      |> Barragenspt.Repo.all()
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

    {:ok, socket |> assign(dams: dams, basin: basin.basin)}
  end

  def handle_params(%{"id" => id}, _url, socket) do
    {parsed_id, ""} = Integer.parse(id)
    %{basin: basin_name} = basin = Basins.get(parsed_id)

    data = Stats.for_basin(basin)

    lines = [%{k: basin_name, v: Colors.lookup(id)}]

    {:noreply, push_event(socket, "update_chart", %{data: data, lines: lines})}
  end
end
