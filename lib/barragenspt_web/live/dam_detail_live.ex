defmodule BarragensptWeb.DamDetailLive do
  use BarragensptWeb, :live_view
  alias Barragenspt.Hydrometrics.Dams
  alias Barragenspt.Geo.Coordinates
  alias Barragenspt.Mappers.Colors

  def handle_event("change_window", %{"value" => value}, socket) do
    id = socket.assigns.dam.site_id

    %{current_storage: current_storage} = Dams.current_storage(id)

    data =
      case value do
        "y" <> val ->
          {int_value, ""} = Integer.parse(val)
          Dams.monthly_stats(id, int_value)

        "m" <> val ->
          {int_value, ""} = Integer.parse(val)
          Dams.daily_stats(id, int_value)
      end

    lines =
      [%{k: "Observado", v: Colors.lookup_capacity(current_storage)}] ++
        [%{k: "Média", v: "grey"}]

    socket = push_event(socket, "update_chart", %{data: data, lines: lines})

    {:noreply, socket}
  end

  def handle_params(%{"id" => id} = params, _url, socket) do
    dam = Dams.get(id)
    data = Dams.monthly_stats(id)
    %{current_storage: current_storage} = Dams.current_storage(id)

    lines =
      [%{k: "Observado", v: Colors.lookup_capacity(current_storage)}] ++
        [%{k: "Média", v: "grey"}]

    dam = prepare_dam_metadata(dam)

    socket =
      socket
      |> assign(dam: dam)
      |> assign(current_capacity: current_storage)
      |> push_event("update_chart", %{data: data, lines: lines})
      |> push_event("enable_tabs", %{})

    if(params["nz"]) do
      {:noreply, socket}
    else
      %{lat: lat, lon: lon} = Coordinates.from_dam(dam)
      {:noreply, push_event(socket, "zoom_map", %{center: [lon, lat]})}
    end
  end

  defp prepare_dam_metadata(dam) do
    allowed_keys = [
      "Barragem",
      "Albufeira",
      "Identificação",
      "Dados Técnicos",
      "Bacia Hidrográfica"
    ]

    basin_data = Map.get(dam.metadata, "Bacia Hidrográfica")

    new_meta =
      dam.metadata
      |> Map.take(allowed_keys)
      |> Map.drop(["Bacia Hidrográfica"])
      |> Map.put("Bacia", basin_data)

    Map.put(dam, :metadata, new_meta)
  end
end
