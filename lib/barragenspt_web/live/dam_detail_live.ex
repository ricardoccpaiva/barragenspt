defmodule BarragensptWeb.DamDetailLive do
  use BarragensptWeb, :live_view
  import Ecto.Query
  alias Barragenspt.Hydrometrics.Stats

  def handle_params(%{"id" => id}, _url, socket) do
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

    result =
      socket
      |> assign(dam: dam)
      |> push_event("update_chart", %{data: data, lines: lines})

    {:noreply, result}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
