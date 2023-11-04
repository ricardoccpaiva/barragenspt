defmodule BarragensptWeb.HomepageLive do
  use BarragensptWeb, :live_view
  alias Barragenspt.Mappers.Colors
  alias Barragenspt.Geo.Coordinates
  alias Barragenspt.Hydrometrics.{Dams, Basins}

  def mount(_, _session, socket) do
    basins_summary = get_data()
    usage_types = Dams.usage_types()
    rivers = Dams.get_river_names()

    socket =
      socket
      |> assign(basins_summary: basins_summary, rivers: rivers, usage_types: usage_types)
      |> push_event("zoom_map", %{})
      |> push_event("enable_tabs", %{})

    {:ok, socket}
  end

  def handle_params(%{"basin_id" => id, "country" => "es"}, _url, socket) do
    %{id: _id, basin_name: basin_name, current_pct: current_pct, capacity_color: capacity_color} =
      Barragenspt.Hydrometrics.EmbalsesNet.basin_info(id)

    socket =
      socket
      |> assign(basin_id: id)
      |> assign(spain: true)
      |> assign(basin: basin_name)
      |> assign(current_pct: current_pct)
      |> assign(capacity_color: capacity_color)
      |> assign(basin_detail_class: "sidenav sidenav-short detail_class_visible")
      |> assign(dam_detail_class: "sidenav sidenav-short detail_class_invisible")

    {:noreply, socket}
  end

  def handle_params(%{"basin_id" => id}, _url, socket) do
    usage_types = Map.get(socket.assigns, :selected_usage_types, [])

    stats = Basins.monthly_stats_for_basin(id, usage_types)
    bounding_box = Dams.bounding_box(id)
    basin_summary = get_basin_summary(id, usage_types)

    %{name: basin_name, current_storage: current_storage} = Basins.get_storage(id)

    chart_lines = [
      %{k: "Observado", v: Colors.lookup_capacity(current_storage)},
      %{k: "Média", v: "grey"}
    ]

    socket =
      socket
      |> assign(basin_id: id)
      |> assign(
        basin_summary: basin_summary,
        basin: basin_name,
        usage_types: Dams.usage_types()
      )
      |> assign(spain: false)
      |> assign(basin_detail_class: "sidenav detail_class_visible")
      |> assign(dam_detail_class: "sidenav detail_class_invisible")
      |> push_event("update_chart", %{kind: :basin, data: stats, lines: chart_lines})
      |> push_event("zoom_map", %{basin_id: id, bounding_box: bounding_box})
      |> push_event("enable_tabs", %{})

    {:noreply, socket}
  end

  def handle_params(%{"dam_id" => id} = params, _url, socket) do
    chart_window_value = Map.get(socket.assigns, :chart_window_value, "y2")

    dam = Dams.get(id)

    data = get_data_for_period(id, chart_window_value)

    %{current_storage: current_storage} = Dams.current_storage(id)
    current_storage_color = Colors.lookup_capacity(current_storage)

    lines =
      [%{k: "Observado", v: current_storage_color}] ++
        [%{k: "Média", v: "grey"}]

    last_data_point =
      id
      |> Dams.last_data_point()
      |> then(fn %{last_data_point: last_data_point} -> last_data_point end)
      |> Timex.format!("{D}/{M}/{YYYY}")

    dam = prepare_dam_metadata(dam)

    usage_types = Dams.usage_types(dam.site_id)

    bounding_box = Coordinates.bounding_box(id)

    socket =
      socket
      |> assign(dam: dam)
      |> assign(current_capacity: current_storage)
      |> assign(basin_detail_class: "sidenav detail_class_invisible")
      |> assign(dam_detail_class: "sidenav detail_class_visible")
      |> assign(search_results_class: "dropdown-content detail_class_invisible")
      |> assign(dam_usage_types: usage_types)
      |> assign(last_data_point: last_data_point)
      |> push_event("update_chart", %{
        kind: :dam,
        data: data,
        lines: lines
      })

    if(params["nz"]) do
      {:noreply, socket}
    else
      {:noreply,
       push_event(socket, "zoom_map", %{
         site_id: id,
         bounding_box: bounding_box,
         current_storage_color: current_storage_color
       })}
    end
  end

  def handle_params(_params, _url, socket) do
    socket = %{socket | assigns: Map.delete(socket.assigns, :basin)}
    socket = %{socket | assigns: Map.delete(socket.assigns, :basin_id)}

    visible_site_ids =
      socket.assigns
      |> Map.get(:selected_usage_types, [])
      |> Dams.current_storage()
      |> Enum.map(fn d -> d.site_id end)

    socket =
      socket
      |> push_event("zoom_map", %{})
      |> assign(basin_detail_class: "sidenav detail_class_invisible")
      |> assign(dam_detail_class: "sidenav detail_class_invisible")
      |> assign(river_detail_class: "sidenav detail_class_invisible")
      |> push_event("update_dams_visibility", %{visible_site_ids: visible_site_ids})

    {:noreply, socket}
  end

  defp get_basin_summary(id, usage_types) do
    id
    |> Basins.summary_stats(usage_types)
    |> Enum.map(fn %{current_storage: current_storage} = m ->
      Map.put(
        m,
        :capacity_color,
        current_storage |> Decimal.round(1) |> Decimal.to_float() |> Colors.lookup_capacity()
      )
    end)
  end

  defp get_data(basin_id \\ nil, usage_types \\ []) do
    Basins.summary_stats(usage_types)
    |> Enum.reject(fn {bid, _n, _cs, _v} -> basin_id && bid != basin_id end)
    |> Enum.map(fn {basin_id, name, current_storage, value} ->
      %{
        id: basin_id,
        name: name,
        current_storage: current_storage,
        average_historic_value: value,
        capacity_color: current_storage |> Decimal.to_float() |> Colors.lookup_capacity()
      }
    end)
  end

  defp get_data_for_period(id, value) do
    case value do
      "y" <> val ->
        {int_value, ""} = Integer.parse(val)
        discharge_data = Dams.discharge_monthly_stats(id, int_value)

        data =
          Enum.map(discharge_data, fn dd ->
            %{
              outflow: dd.value,
              date: dd.date,
              basin: "Descarga"
            }
          end)

        Dams.monthly_stats(id, int_value) ++ data

      "m" <> val ->
        {int_value, ""} = Integer.parse(val)

        discharge_data = Dams.discharge_stats(id, int_value, :month)

        data =
          Enum.map(discharge_data, fn dd ->
            %{
              outflow: dd.value,
              date: dd.date,
              basin: "Descarga"
            }
          end)

        Dams.daily_stats(id, int_value) ++ data

      "s" <> val ->
        {int_value, ""} = Integer.parse(val)
        discharge_data = Dams.discharge_stats(id, int_value, :week)

        data =
          Enum.map(discharge_data, fn dd ->
            %{
              outflow: dd.value,
              date: dd.date,
              basin: "Descarga"
            }
          end)

        Dams.hourly_stats(id, int_value) ++ data
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

  def handle_event("select_river", %{"basin_id" => basin_id, "river_name" => river_name}, socket) do
    visible_site_ids =
      river_name
      |> Dams.get_dams_by_river()
      |> Enum.map(fn d -> d.site_id end)

    bounding_box = Dams.bounding_box(visible_site_ids)

    basin_summary =
      basin_id
      |> get_basin_summary([])
      |> Enum.filter(fn %{site_id: site_id} ->
        Enum.any?(visible_site_ids, fn vsid -> vsid == site_id end)
      end)

    socket =
      socket
      |> assign(basin_detail_class: "sidenav detail_class_invisible")
      |> assign(dam_detail_class: "sidenav detail_class_invisible")
      |> assign(river_detail_class: "sidenav detail_class_visible")
      |> assign(river: river_name, basin_summary: basin_summary)
      |> push_event("zoom_map", %{basin_id: basin_id, bounding_box: bounding_box})
      |> push_event("focus_river", %{basin_id: basin_id, river_name: river_name})
      |> push_event("update_dams_visibility", %{visible_site_ids: visible_site_ids})

    {:noreply, socket}
  end

  def handle_event("select_river", %{}, socket) do
    visible_site_ids = Dams.all() |> Enum.map(fn d -> d.site_id end)

    socket =
      socket
      |> assign(river_detail_class: "sidenav detail_class_invisible")
      |> push_event("zoom_map", %{})
      |> push_event("update_dams_visibility", %{visible_site_ids: visible_site_ids})

    {:noreply, socket}
  end

  def handle_event(
        "update_selected_usage_types",
        %{"usage_type" => usage_type, "checked" => checked},
        socket
      ) do
    usage_types = Map.get(socket.assigns, :selected_usage_types, [])

    usage_types =
      if(checked) do
        Enum.concat(usage_types, [usage_type])
      else
        Enum.reject(usage_types, fn ut -> ut == usage_type end)
      end

    tasks = [
      Task.async(fn -> {:basins_summary, get_data(socket.assigns[:basin_id], usage_types)} end),
      Task.async(fn ->
        ret =
          if socket.assigns[:basin_id] do
            get_basin_summary(socket.assigns[:basin_id], usage_types)
          else
            []
          end

        {:basin_summary, ret}
      end),
      Task.async(fn ->
        ret =
          usage_types
          |> Dams.current_storage()
          |> Enum.reject(fn d ->
            socket.assigns[:basin_id] && socket.assigns[:basin_id] != d.basin_id
          end)
          |> Enum.map(fn d -> d.site_id end)

        {:visible_site_ids, ret}
      end)
    ]

    tasks_result = Task.await_many(tasks)

    {:basins_summary, basins_summary} =
      Enum.find(tasks_result, fn {k, _ret} -> k == :basins_summary end)

    {:basin_summary, basin_summary} =
      Enum.find(tasks_result, fn {k, _ret} -> k == :basin_summary end)

    {:visible_site_ids, visible_site_ids} =
      Enum.find(tasks_result, fn {k, _ret} -> k == :visible_site_ids end)

    socket =
      socket
      |> assign(selected_usage_types: usage_types, basin_summary: basin_summary)
      |> push_event("update_basins_summary", %{basins_summary: basins_summary})
      |> push_event("update_dams_visibility", %{visible_site_ids: visible_site_ids})

    {:noreply, socket}
  end

  def handle_event("search_dam", %{"search_term" => search_term}, socket) do
    usage_types = Map.get(socket.assigns, :selected_usage_types, [])

    dam_names =
      case search_term do
        "" -> []
        _ -> Barragenspt.Hydrometrics.Dams.search(search_term, usage_types)
      end

    site_ids = Enum.map(dam_names, fn %{id: id, name: _name} -> id end)
    dams_current_storage = Dams.current_storage_for_sites(site_ids)

    dam_names =
      Enum.map(dam_names, fn %{id: id, name: name} ->
        site_storage_info =
          Enum.find(dams_current_storage, %{current_storage: 0}, fn dcs -> dcs.site_id == id end)

        %{
          id: id,
          name: name,
          current_storage: site_storage_info.current_storage,
          current_storage_color: Colors.lookup_capacity(site_storage_info.current_storage)
        }
      end)

    socket =
      socket
      |> assign(dam_names: dam_names)
      |> assign(search_results_class: "dropdown-content")

    {:noreply, socket}
  end

  def handle_event("basin_change_window", %{"value" => value}, socket) do
    id = socket.assigns.basin_id
    usage_types = Map.get(socket.assigns, :selected_usage_types, [])

    %{current_storage: current_storage} = Basins.get_storage(id)

    data =
      case value do
        "y" <> val ->
          {int_value, ""} = Integer.parse(val)
          Basins.monthly_stats_for_basin(id, usage_types, int_value)

        "m" <> val ->
          {int_value, ""} = Integer.parse(val)
          Basins.daily_stats_for_basin(id, usage_types, int_value)
      end

    lines =
      [%{k: "Observado", v: Colors.lookup_capacity(current_storage)}] ++
        [%{k: "Média", v: "grey"}]

    socket = push_event(socket, "update_chart", %{kind: :basin, data: data, lines: lines})

    {:noreply, socket}
  end

  def handle_event("dam_change_window", %{"value" => value}, socket) do
    id = socket.assigns.dam.site_id

    %{current_storage: current_storage} = Dams.current_storage(id)

    data = get_data_for_period(id, value)

    lines =
      [%{k: "Observado", v: Colors.lookup_capacity(current_storage)}] ++
        [%{k: "Média", v: "grey"}] ++
        [%{k: "Descarga", v: "#91CC75"}]

    socket =
      socket
      |> assign(chart_window_value: value)
      |> push_event("update_chart", %{kind: :dam, data: data, lines: lines})

    {:noreply, socket}
  end
end
