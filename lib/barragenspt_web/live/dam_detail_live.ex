defmodule BarragensptWeb.DamDetailLive do
  use BarragensptWeb, :live_view
  import Ecto.Query
  alias Barragenspt.Mappers.Colors

  def mount(_params, _session, socket) do
    query =
      from p in Barragenspt.Hydrometrics.Dam,
        group_by: [p.basin_id, p.basin],
        select: %{basin: p.basin, id: p.basin_id}

    basins =
      query
      |> Barragenspt.Repo.all()
      |> Enum.map(fn basin -> Map.put(basin, :pct, :rand.uniform(100)) end)
      |> Enum.map(fn basin -> Map.put(basin, :pct_2, :rand.uniform(100)) end)
      |> Enum.map(fn basin -> Map.put(basin, :color, Colors.lookup(basin.id)) end)
      |> Enum.map(fn basin ->
        Map.put(basin, :capacity_color, Colors.lookup_capacity(basin.pct))
      end)

    {:ok, assign(socket, basins: basins)}
  end

  def handle_params(%{"id" => id}, _url, socket) do
    dam = Barragenspt.Repo.one(from p in Barragenspt.Hydrometrics.Dam, where: p.site_id == ^id)

    {:noreply, socket |> assign(dam: dam.name)}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
