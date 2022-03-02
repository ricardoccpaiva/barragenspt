defmodule BarragensptWeb.DamDetailLive do
  use BarragensptWeb, :live_view
  import Ecto.Query
  alias Barragenspt.Hydrometrics.Stats
  alias Barragenspt.Geo.Coordinates

  def handle_params(%{"id" => id} = params, _url, socket) do
    dam = Barragenspt.Repo.one(from(p in Barragenspt.Hydrometrics.Dam, where: p.site_id == ^id))
    data = Stats.for_site(id)
    lines = [%{k: id, v: "grey"}]

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
