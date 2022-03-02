defmodule BarragensptWeb.HomepageLive do
  use BarragensptWeb, :live_view
  import Ecto.Query
  alias Barragenspt.Mappers.Colors
  alias Barragenspt.Hydrometrics.Stats
  alias Barragenspt.Hydrometrics.BasinStorage
  alias Barragenspt.Hydrometrics.Basins

  def mount(_params, _session, socket) do
    query = from(p in BasinStorage)

    basins =
      query
      |> Barragenspt.Repo.all()
      |> Enum.map(fn %{current_storage: current_storage} = basin ->
        rounded_storage = current_storage |> Decimal.round(1) |> Decimal.to_float()

        Map.replace(
          basin,
          :current_storage,
          rounded_storage
        )
      end)
      |> Enum.map(fn basin -> Map.put(basin, :pct_2, :rand.uniform(100)) end)
      |> Enum.map(fn basin -> Map.put(basin, :color, Colors.lookup(basin.id)) end)
      |> Enum.map(fn basin ->
        Map.put(basin, :capacity_color, Colors.lookup_capacity(basin.current_storage))
      end)

    {:ok, assign(socket, basins: basins)}
  end

  def handle_params(_params, _url, socket) do
    all_basins = Basins.all()
    data_to_feed = Stats.for_basins()

    lines =
      Enum.map(all_basins, fn %{id: id, basin: basin} ->
        %{k: basin, v: Colors.lookup(id)}
      end)

    socket =
      socket
      |> push_event("update_chart", %{data: data_to_feed, lines: lines})
      |> push_event("zoom_map", %{})

    {:noreply, socket}
  end
end
