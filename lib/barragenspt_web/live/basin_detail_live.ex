defmodule BarragensptWeb.BasinDetailLive do
  use BarragensptWeb, :live_view
  import Ecto.Query
  alias Barragenspt.Mappers.Colors

  def mount(_params, _session, socket) do
    {:ok, assign(socket, %{})}
  end

  def handle_params(%{"id" => id}, _url, socket) do
    query = from p in Barragenspt.Hydrometrics.Dam, where: p.basin_id == ^String.to_integer(id)

    dams =
      query
      |> Barragenspt.Repo.all()
      |> Enum.map(fn dam -> Map.put(dam, :pct, :rand.uniform(100)) end)
      |> Enum.map(fn basin -> Map.put(basin, :pct_2, :rand.uniform(100)) end)
      |> Enum.map(fn dam ->
        Map.put(dam, :capacity_color, Colors.lookup_capacity(dam.pct))
      end)

    {:noreply, socket |> assign(dams: dams, basin: Enum.at(dams, 0).basin)}
  end
end
