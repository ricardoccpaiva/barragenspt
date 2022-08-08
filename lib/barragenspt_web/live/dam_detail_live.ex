defmodule BarragensptWeb.DamDetailLive do
  use BarragensptWeb, :live_view
  alias Barragenspt.Hydrometrics.Dams
  alias Barragenspt.Geo.Coordinates
  alias Barragenspt.Mappers.Colors

  def handle_event("change_window", %{"value" => value} = args, socket) do
    id = socket.assigns.dam.site_id

    %{current_storage: current_storage} = Dams.current_storage(id)

    data = get_data_for_period(id, value)

    lines =
      [%{k: "Observado", v: Colors.lookup_capacity(current_storage)}] ++
        [%{k: "Média", v: "grey"}]

    socket =
      socket
      |> assign(chart_window_value: value)
      |> push_event("update_chart", %{data: data, lines: lines})

    {:noreply, socket}
  end

  def handle_params(%{"id" => id} = params, _url, socket) do
    chart_window_value = Map.get(socket.assigns, :chart_window_value, "y2")

    dam = Dams.get(id)

    data = get_data_for_period(id, chart_window_value)

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

    if(params["nz"]) do
      {:noreply, socket}
    else
      %{lat: lat, lon: lon} = Coordinates.from_dam(dam)
      {:noreply, push_event(socket, "zoom_map", %{center: [lon, lat]})}
    end
  end

  defp get_data_for_period(id, value) do
    case value do
      "y" <> val ->
        {int_value, ""} = Integer.parse(val)
        Dams.monthly_stats(id, int_value)

      "m" <> val ->
        {int_value, ""} = Integer.parse(val)
        Dams.daily_stats(id, int_value)
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
