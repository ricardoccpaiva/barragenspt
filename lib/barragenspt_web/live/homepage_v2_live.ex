defmodule BarragensptWeb.HomepageV2Live do
  use BarragensptWeb, :live_view
  alias Barragenspt.Mappers.Colors
  alias Barragenspt.Geo.Coordinates
  alias Barragenspt.Hydrometrics.{Dams, Basins}
  require Logger

  def mount(_, _session, socket) do
    dams =
      []
      |> Dams.current_storage()
      |> Enum.map(fn d -> build_dam_data(d) end)

    usage_types = Dams.usage_types()
    rivers = Dams.get_river_names()
    basins = Basins.summary_stats([])

    socket =
      socket
      |> assign(
        rivers: rivers,
        usage_types: usage_types,
        dams: dams,
        basin_card: nil
      )
      |> push_event("zoom_map", %{})
      |> push_event("draw_dams", %{dams: dams})
      |> push_event("draw_basins", %{basins: basins})

    {:ok, socket}
  end

  defp build_dam_data(dam) do
    %{
      id: dam.site_id,
      basin_id: dam.basin_id,
      site_id: dam.site_id,
      dam_name: dam.site_name,
      basin_name: dam.basin_name,
      current_storage:
        dam.current_storage |> Decimal.new() |> Decimal.round(2) |> Decimal.to_float(),
      colected_at: dam.colected_at,
      coordinates: Coordinates.from_dam(dam.site_id)
    }
  end

  def handle_params(%{"basin_id" => id}, _url, socket) do
    usage_types = Map.get(socket.assigns, :selected_usage_types, [])

    summary = Basins.summary_stats(id, usage_types)
    daily_stats = Basins.daily_stats_for_basin(id, usage_types, 12)
    monthly_stats = Basins.monthly_stats_for_basin(id, usage_types, 2)
    bounding_box = Dams.bounding_box(id)

    %{name: basin_name} = Basins.get(id)

    socket =
      socket
      |> assign(basin_id: id)
      |> assign(basin_summary: summary)
      |> assign(basin_card: build_basin_card(basin_name, summary, daily_stats, monthly_stats))
      |> push_event("zoom_map", %{basin_id: id, bounding_box: bounding_box})

    {:noreply, socket}
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
      |> assign(basin_card: build_basin_card_spain(basin_name, current_pct, capacity_color))
      |> assign(basin_detail_class: "sidenav sidenav-short detail_class_visible")
      |> assign(dam_detail_class: "sidenav sidenav-short detail_class_invisible")

    {:noreply, socket}
  end

  def handle_params(%{"dam_id" => id} = params, _url, socket) do
    dam = Dams.get(id)

    %{current_storage: current_storage} = Dams.current_storage(id)
    current_storage_color = Colors.lookup_capacity(current_storage)

    spec =
      id
      |> get_data_for_period("y2")
      |> Enum.map(fn d ->
        %{Data: Calendar.strftime(d.date, "%b %d %Y"), "% Armazenamento": d.value, Tipo: d.basin}
      end)
      |> get_vega_spec()

    last_data_point =
      id
      |> Dams.last_data_point()
      |> then(fn %{last_data_point: last_data_point} -> last_data_point end)
      |> Timex.format!("{D}/{M}/{YYYY}")

    %{value: last_elevation, colected_at: elevation_date} =
      case Dams.last_elevation(id) do
        %{value: last_elevation, colected_at: elevation_date} ->
          %{value: last_elevation, colected_at: Timex.format!(elevation_date, "{D}/{M}/{YYYY}")}

        _ ->
          %{value: 0, colected_at: "n/a"}
      end

    dam = prepare_dam_metadata(dam)

    usage_types = Dams.usage_types(dam.site_id)

    bounding_box = Coordinates.bounding_box(id)

    socket =
      socket
      |> assign(dam: dam)
      |> assign(current_capacity: current_storage)
      |> assign(basin_card: nil)
      |> assign(basin_detail_class: "sidenav detail_class_invisible")
      |> assign(dam_detail_class: "sidenav detail_class_visible")
      |> assign(search_results_class: "dropdown-content detail_class_invisible")
      |> assign(dam_usage_types: usage_types)
      |> assign(last_data_point: last_data_point)
      |> assign(last_elevation: last_elevation)
      |> assign(last_elevation_date: elevation_date)
      |> push_event("draw", %{"spec" => spec})

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
    Logger.info("------> handle_params")
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
      |> assign(basin_card: nil)
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

  defp build_basin_card(name, summary, daily_stats, monthly_stats) do
    dams =
      Enum.map(summary, fn item ->
        %{
          id: item.site_id,
          name: normalize_dam_name(item.site_name),
          observed: item.observed_value,
          average: item.historical_average,
          observed_class: badge_class(item.observed_value),
          average_class: badge_class(item.historical_average),
          observed_date_label: format_reference_date(Map.get(item, :colected_at))
        }
      end)

    latest_stat = List.last(daily_stats)
    avg_observed = latest_stat && latest_stat.observed_value
    month_point = period_point(daily_stats, 31, 1)
    month_value = month_point && month_point.observed_value
    month_change = period_change(daily_stats, 31, 1)
    month_display_change = invert_change(month_change)
    year_point = period_point(monthly_stats, 365, 45)
    year_value = year_point && year_point.observed_value
    year_change = period_change(monthly_stats, 365, 45)
    year_display_change = invert_change(year_change)

    %{
      name: name,
      dams_count: length(summary),
      avg_observed: round_or_nil(avg_observed),
      month_value: round_or_nil(month_value),
      month_change_label: format_period_change(month_display_change),
      month_reference_label: format_reference_date(month_point && month_point.date),
      month_trend_arrow: trend_arrow(month_display_change),
      month_trend_class: trend_class(month_display_change),
      month_trend_badge_class: trend_badge_class(month_display_change),
      year_value: round_or_nil(year_value),
      year_change_label: format_period_change(year_display_change),
      year_reference_label: format_reference_date(year_point && year_point.date),
      year_trend_arrow: trend_arrow(year_display_change),
      year_trend_class: trend_class(year_display_change),
      year_trend_badge_class: trend_badge_class(year_display_change),
      basin_chart_series: monthly_stats,
      total_storage_label: build_total_storage_label(summary, avg_observed),
      dams: dams
    }
  end

  defp build_total_storage_label(summary, avg_observed) do
    sum = Enum.reduce(summary, 0, fn item, acc -> item.total_capacity + acc end)

    current_storage = (sum * avg_observed / 100) |> Float.round(2)

    "#{current_storage} hm³"
  end

  defp build_basin_card_spain(basin_name, current_pct, capacity_color) do
    %{
      name: basin_name,
      dams_count: nil,
      avg_observed: round_or_nil(current_pct),
      avg_historical: nil,
      month_value: nil,
      month_change: nil,
      month_change_label: "n/a",
      month_reference_label: "n/a",
      trend: "n/a",
      trend_arrow: "→",
      trend_class: "text-slate-500",
      year_value: nil,
      year_change: nil,
      year_change_label: "n/a",
      year_reference_label: "n/a",
      year_trend_arrow: "→",
      year_trend_class: "text-slate-500",
      month_trend_badge_class: "bg-slate-100 text-slate-600",
      year_trend_badge_class: "bg-slate-100 text-slate-600",
      color: capacity_color || "#94a3b8",
      basin_chart_series: [],
      total_storage_label: "—",
      dams: []
    }
  end

  defp badge_class(nil), do: "bg-slate-100 text-slate-600"

  defp badge_class(%Decimal{} = value) do
    value
    |> Decimal.to_float()
    |> badge_class()
  end

  defp badge_class(value) when is_number(value) do
    cond do
      value <= 20 -> "bg-red-100 text-red-700"
      value <= 40 -> "bg-orange-100 text-orange-700"
      value <= 50 -> "bg-amber-100 text-amber-700"
      value <= 60 -> "bg-lime-100 text-lime-700"
      value <= 80 -> "bg-green-100 text-green-700"
      true -> "bg-emerald-100 text-emerald-700"
    end
  end

  defp normalize_dam_name(nil), do: nil

  defp normalize_dam_name(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.replace(~r/^albufeira\s+(de|da|do|das|dos)\s+/i, "")
  end

  defp round_or_nil(nil), do: nil
  defp round_or_nil(value), do: Float.round(value, 1)

  defp period_point([], _target_days, _max_distance_days), do: nil

  defp period_point(stats, target_days, max_distance_days) do
    latest = List.last(stats)

    with %{date: latest_date} <- latest do
      target_date = Timex.shift(latest_date, days: -target_days)

      target_point =
        Enum.min_by(
          stats,
          fn item -> abs(Timex.diff(item.date, target_date, :days)) end,
          fn -> nil end
        )

      case target_point do
        %{date: point_date} = point ->
          if abs(Timex.diff(point_date, target_date, :days)) <= max_distance_days do
            point
          else
            nil
          end

        _ ->
          nil
      end
    else
      _ -> nil
    end
  end

  defp period_value(stats, target_days, max_distance_days) do
    case period_point(stats, target_days, max_distance_days) do
      %{observed_value: point_value} -> point_value
      _ -> nil
    end
  end

  defp period_change([], _target_days, _max_distance_days), do: nil

  defp period_change(stats, target_days, max_distance_days) do
    latest = List.last(stats)

    with %{observed_value: latest_value} <- latest,
         point_value when is_number(point_value) <-
           period_value(stats, target_days, max_distance_days) do
      Float.round(latest_value - point_value, 1)
    else
      _ -> nil
    end
  end

  defp format_period_change(nil), do: "n/a"

  defp format_period_change(change) when is_number(change) do
    sign = if change > 0, do: "+", else: ""
    "#{sign}#{Float.round(change, 1)}%"
  end

  defp format_reference_date(nil), do: "n/a"

  defp format_reference_date(date) do
    Timex.format!(date, "{0D}/{0M}/{YYYY}")
  end

  defp invert_change(nil), do: nil
  defp invert_change(change) when is_number(change), do: change * -1

  defp trend_arrow(nil), do: "→"
  defp trend_arrow(change) when change > 0, do: "↑"
  defp trend_arrow(change) when change < 0, do: "↓"
  defp trend_arrow(_change), do: "→"

  defp trend_class(nil), do: "text-slate-500"
  defp trend_class(change) when change > 0, do: "text-emerald-600"
  defp trend_class(change) when change < 0, do: "text-rose-600"
  defp trend_class(_change), do: "text-slate-500"

  defp trend_badge_class(nil), do: "bg-slate-100 text-slate-600"
  defp trend_badge_class(change) when change > 0, do: "bg-emerald-50 text-emerald-700"
  defp trend_badge_class(change) when change < 0, do: "bg-rose-50 text-rose-700"
  defp trend_badge_class(_change), do: "bg-slate-100 text-slate-600"

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

        id
        |> Dams.discharge_monthly_stats(int_value)
        |> Enum.map(fn dd -> %{value: dd.value, date: dd.date, basin: "Descarga"} end)
        |> Kernel.++(Dams.monthly_stats(id, int_value))

      "m" <> val ->
        {int_value, ""} = Integer.parse(val)

        id
        |> Dams.discharge_stats(int_value, :month)
        |> Enum.map(fn dd -> %{value: dd.value, date: dd.date, basin: "Descarga"} end)
        |> Kernel.++(Dams.daily_stats(id, int_value))

      "s" <> val ->
        {int_value, ""} = Integer.parse(val)

        id
        |> Dams.discharge_stats(int_value, :week)
        |> Enum.map(fn dd -> %{value: dd.value, date: dd.date, basin: "Descarga"} end)
        |> Kernel.++(Dams.hourly_stats(id, int_value))
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

    spec =
      case value do
        "y" <> val ->
          {int_value, ""} = Integer.parse(val)

          id
          |> Basins.monthly_stats_for_basin(usage_types, int_value)
          |> Enum.map(fn d ->
            %{
              Data: Calendar.strftime(d.date, "%b %d %Y"),
              "% Armazenamento": d.value,
              Tipo: d.basin
            }
          end)
          |> get_vega_spec_for_basin()

        "m" <> val ->
          {int_value, ""} = Integer.parse(val)

          id
          |> Basins.daily_stats_for_basin(usage_types, int_value)
          |> Enum.map(fn d ->
            %{
              Data: Calendar.strftime(d.date, "%b %d %Y"),
              "% Armazenamento": d.value,
              Tipo: d.basin
            }
          end)
          |> get_vega_spec_for_basin()
      end

    socket =
      socket
      |> assign(chart_window_value: value)
      |> push_event("draw", %{"spec" => spec})

    {:noreply, socket}
  end

  def handle_event("dam_change_window", %{"value" => value}, socket) do
    id = socket.assigns.dam.site_id

    spec =
      id
      |> get_data_for_period(value)
      |> Enum.map(fn d ->
        %{Data: Calendar.strftime(d.date, "%b %d %Y"), "% Armazenamento": d.value, Tipo: d.basin}
      end)
      |> get_vega_spec()

    socket =
      socket
      |> assign(chart_window_value: value)
      |> push_event("draw", %{"spec" => spec})

    {:noreply, socket}
  end

  defp get_vega_spec(data) do
    VegaLite.new(width: :container, height: :container)
    |> VegaLite.encode_field(:x, "Data", type: :temporal, title: "")
    |> VegaLite.layers([
      VegaLite.new()
      |> VegaLite.data_from_values(data)
      |> VegaLite.transform(filter: "datum.Tipo == 'Descarga'")
      |> VegaLite.layers([
        VegaLite.new()
        |> VegaLite.mark(:bar),
        VegaLite.new()
        |> VegaLite.mark(:point)
        |> VegaLite.transform(filter: [param: "hover", empty: false])
      ])
      |> VegaLite.encode_field(:y, "% Armazenamento",
        title: "Descarga (㎥/s)",
        type: :quantitative,
        scale: %{zero: false}
      )
      |> VegaLite.encode(:color,
        field: "Tipo",
        type: :nominal,
        legend: %{orient: "bottom", title: ""}
      ),
      VegaLite.new()
      |> VegaLite.data_from_values(data)
      |> VegaLite.transform(filter: "datum.Tipo != 'Descarga'")
      |> VegaLite.layers([
        VegaLite.new()
        |> VegaLite.mark(:line, interpolate: :natural),
        VegaLite.new()
        |> VegaLite.mark(:point)
        |> VegaLite.transform(filter: [param: "hover", empty: false])
      ])
      |> VegaLite.encode_field(:y, "% Armazenamento",
        type: :quantitative,
        scale: %{zero: false},
        scale: %{domain: [0, 100]}
      )
      |> VegaLite.encode(:color,
        field: "Tipo",
        type: :nominal,
        legend: %{orient: "bottom", title: ""}
      ),
      VegaLite.new()
      |> VegaLite.data_from_values(data)
      |> VegaLite.transform(pivot: "Tipo", value: "% Armazenamento", groupby: ["Data"])
      |> VegaLite.mark(:rule)
      |> VegaLite.encode(:opacity,
        condition: %{value: 0.3, param: "hover", empty: false},
        value: 0
      )
      |> VegaLite.encode(:tooltip, [
        [field: "Data", type: :temporal],
        [field: "Média", type: :quantitative],
        [field: "Observado", type: :quantitative],
        [field: "Descarga", type: :quantitative]
      ])
      |> VegaLite.param("hover",
        select: [
          type: :point,
          fields: ["Data"],
          nearest: true,
          empty: false,
          on: :mouseover,
          clear: :mouseout
        ]
      )
    ])
    |> VegaLite.resolve(:scale, y: :independent)
    |> VegaLite.to_spec()
  end

  defp get_vega_spec_for_basin(data) do
    VegaLite.new(width: :container, height: :container)
    |> VegaLite.encode_field(:x, "Data", type: :temporal, title: "")
    |> VegaLite.layers([
      VegaLite.new()
      |> VegaLite.data_from_values(data)
      |> VegaLite.layers([
        VegaLite.new()
        |> VegaLite.mark(:line, interpolate: :natural),
        VegaLite.new()
        |> VegaLite.mark(:point)
        |> VegaLite.transform(filter: [param: "hover", empty: false])
      ])
      |> VegaLite.encode_field(:y, "% Armazenamento",
        type: :quantitative,
        scale: %{zero: false},
        scale: %{domain: [0, 100]}
      )
      |> VegaLite.encode(:color,
        field: "Tipo",
        type: :nominal,
        legend: %{orient: "bottom", title: ""}
      ),
      VegaLite.new()
      |> VegaLite.data_from_values(data)
      |> VegaLite.transform(pivot: "Tipo", value: "% Armazenamento", groupby: ["Data"])
      |> VegaLite.mark(:rule)
      |> VegaLite.encode(:opacity,
        condition: %{value: 0.3, param: "hover", empty: false},
        value: 0
      )
      |> VegaLite.encode(:tooltip, [
        [field: "Data", type: :temporal],
        [field: "Média", type: :quantitative],
        [field: "Observado", type: :quantitative]
      ])
      |> VegaLite.param("hover",
        select: [
          type: :point,
          fields: ["Data"],
          nearest: true,
          on: :mouseover,
          clear: :mouseout
        ]
      )
    ])
    |> VegaLite.to_spec()
  end
end
