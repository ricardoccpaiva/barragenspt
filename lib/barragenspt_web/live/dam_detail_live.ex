defmodule BarragensptWeb.DamDetailLive do
  use BarragensptWeb, :live_view
  import Ecto.Query
  alias Barragenspt.Hydrometrics.Dams
  alias Barragenspt.Geo.Coordinates
  alias Barragenspt.Mappers.Colors

  def handle_event("change_window", %{"value" => value}, socket) do
    id = socket.assigns.dam.site_id
    {int_value, ""} = Integer.parse(value)
    dam = Barragenspt.Repo.one(from(p in Barragenspt.Hydrometrics.Dam, where: p.site_id == ^id))
    data = Dams.monthly_stats(dam, int_value)
    lines = [%{k: "Observado", v: Colors.lookup(dam.basin_id)}] ++ [%{k: "Média", v: "grey"}]

    socket = push_event(socket, "update_chart", %{data: data, lines: lines})

    {:noreply, socket}
  end

  def handle_params(%{"id" => id} = params, _url, socket) do
    dam = Barragenspt.Repo.one(from(p in Barragenspt.Hydrometrics.Dam, where: p.site_id == ^id))
    data = Dams.monthly_stats(dam)
    lines = [%{k: "Observado", v: Colors.lookup(dam.basin_id)}] ++ [%{k: "Média", v: "grey"}]

    allowed_keys = [
      "Barragem",
      "Albufeira",
      "Identificação",
      "Dados Técnicos",
      "Bacia Hidrográfica"
    ]

    new_meta = Map.take(dam.metadata, allowed_keys)
    dam = Map.put(dam, :metadata, new_meta)

    %{lat: lat, lon: lon} = Coordinates.from_dam(dam)

    socket =
      socket
      |> assign(dam: dam)
      |> push_event("update_chart", %{data: data, lines: lines})
      |> push_event("enable_tabs", %{})

    if(params["nz"]) do
      {:noreply, socket}
    else
      {:noreply, push_event(socket, "zoom_map", %{center: [lon, lat]})}
    end
  end
end
