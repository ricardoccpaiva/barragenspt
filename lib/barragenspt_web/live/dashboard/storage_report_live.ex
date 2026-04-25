defmodule BarragensptWeb.Dashboard.StorageReportLive do
  use BarragensptWeb, :live_view

  on_mount {BarragensptWeb.UserAuth, :require_authenticated}

  alias Barragenspt.Hydrometrics.StorageReport

  @hydro_geojson_source_path Path.expand(
                               "../../../../priv/static/geojson/pt100_hidro.json",
                               __DIR__
                             )
  @external_resource @hydro_geojson_source_path
  @portugal_bounds %{min_lon: -9.7, max_lon: -6.1, min_lat: 36.8, max_lat: 42.2}

  @impl true
  def mount(_params, _session, socket) do
    default_date = monday_of_current_week()

    {:ok,
     socket
     |> assign(:page_title, "Relatório de armazenamento")
     |> assign(:basin_options, StorageReport.list_basins())
     |> assign(:selected_basin, "__all__")
     |> assign(:selected_date, default_date)
     |> assign(:loading_report, false)
     |> assign(:basin_map_image, nil)
     |> assign(:report, nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    selected_basin = selected_basin_param(Map.get(params, "basin"))
    selected_date = parse_basin_date_param(Map.get(params, "date"), monday_of_current_week())

    {:noreply,
     socket
     |> assign(:selected_date, selected_date)
     |> assign(:selected_basin, selected_basin)
     |> assign(:loading_report, false)
     |> assign(:basin_map_image, nil)
     |> assign(:report, nil)}
  end

  @impl true
  def handle_event("select_date", %{"date" => date}, socket) do
    case parse_basin_date_param(date, nil) do
      nil ->
        {:noreply, socket}

      parsed_date ->
        {:noreply,
         push_patch(
           socket,
           to: storage_report_path(socket.assigns.selected_basin, parsed_date)
         )}
    end
  end

  def handle_event("generate_report", _params, socket) do
    send(
      self(),
      {:generate_storage_report, socket.assigns.selected_basin, socket.assigns.selected_date}
    )

    {:noreply,
     socket
     |> assign(:loading_report, true)
     |> assign(:basin_map_image, nil)
     |> assign(:report, nil)}
  end

  def handle_event("select_basin", %{"basin" => "__all__"}, socket) do
    {:noreply,
     push_patch(
       socket,
       to: storage_report_path("__all__", socket.assigns.selected_date)
     )}
  end

  def handle_event("select_basin", %{"basin" => basin}, socket) do
    {:noreply,
     push_patch(
       socket,
       to: storage_report_path(basin, socket.assigns.selected_date)
     )}
  end

  @impl true
  def handle_info({:generate_storage_report, selected_basin, selected_date}, socket) do
    report =
      StorageReport.build(
        basin: selected_basin,
        reference_at: date_to_naive_datetime(selected_date)
      )

    {:noreply,
     socket
     |> assign(:loading_report, false)
     |> assign(:basin_map_image, basin_map_image(report))
     |> assign(:report, report)}
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :sub, :string, required: true
  attr :accent, :string, default: "brand"

  defp metric_card(assigns) do
    ~H"""
    <div class="relative overflow-hidden rounded-2xl border border-slate-200 bg-white p-4 shadow-sm dark:border-slate-700 dark:bg-slate-800">
      <div class={["absolute inset-x-4 bottom-0 h-1 rounded-t-full", accent_bg(@accent)]}></div>
      <p class="text-xs font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400">
        {@label}
      </p>
      <p class="mt-2 text-2xl font-bold tabular-nums text-slate-950 dark:text-slate-50">{@value}</p>
      <p class="mt-2 text-sm text-slate-500 dark:text-slate-400">{@sub}</p>
    </div>
    """
  end

  attr :color, :string, required: true
  attr :label, :string, required: true

  defp legend_item(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-2">
      <span class="h-3.5 w-3.5 rounded" style={"background-color: #{@color}"}></span>
      <span>{@label}</span>
    </span>
    """
  end

  attr :pct, :float, default: nil

  defp pct_with_sparkbar(assigns) do
    ~H"""
    <div class="ml-auto w-20">
      <div class="text-right tabular-nums text-slate-800 dark:text-slate-200">
        {format_pct(@pct)}
      </div>
      <div class="mt-1 h-1 overflow-hidden rounded-full bg-slate-200 dark:bg-slate-700">
        <span
          class="block h-full rounded-full"
          style={"width: #{bar_width(@pct)}%; background-color: #{storage_color(@pct)}"}
        >
        </span>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :class, :string, default: "text-slate-900 dark:text-slate-100"

  defp pill(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1 rounded-full border border-slate-200 bg-white px-2.5 py-1 text-xs shadow-sm dark:border-slate-600 dark:bg-slate-800">
      <span class="text-slate-500 dark:text-slate-400">{@label}</span>
      <strong class={@class}>{@value}</strong>
    </span>
    """
  end

  attr :basin, :map, required: true

  defp mini_map(assigns) do
    ~H"""
    <aside class="aspect-square rounded-xl border border-slate-200 bg-slate-50 p-3 dark:border-slate-700 dark:bg-slate-900/40">
      <div class="mb-2 flex items-center justify-between gap-2 text-xs">
        <p class="font-semibold text-slate-900 dark:text-slate-100">Mapa da bacia</p>
        <p class="text-slate-500 dark:text-slate-400">{@basin.dam_count} ponto(s)</p>
      </div>
      <img
        src={mini_basin_map_image(@basin)}
        alt={"Bacia do #{@basin.name} com pontos das barragens"}
        class="block h-[calc(100%-1.5rem)] w-full rounded-lg object-contain"
      />
    </aside>
    """
  end

  defp scale(_value, same, same, min_out, max_out), do: (min_out + max_out) / 2

  defp scale(value, min_in, max_in, min_out, max_out) do
    min_out + (value - min_in) / (max_in - min_in) * (max_out - min_out)
  end

  defp selected_basin_param(nil), do: "__all__"
  defp selected_basin_param(""), do: "__all__"
  defp selected_basin_param("__all__"), do: "__all__"
  defp selected_basin_param(basin), do: basin

  defp monday_of_current_week do
    today = Date.utc_today()
    monday = Date.add(today, 1 - Date.day_of_week(today))
    monday
  end

  defp earliest_selectable_monday do
    Date.add(monday_of_current_week(), -364)
  end

  defp parse_basin_date_param(nil, fallback), do: fallback

  defp parse_basin_date_param("", fallback), do: fallback

  defp parse_basin_date_param(date_string, _fallback) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        if Date.day_of_week(date) == 1 and
             Date.compare(date, earliest_selectable_monday()) != :lt and
             Date.compare(date, monday_of_current_week()) != :gt do
          date
        else
          nil
        end

      _ ->
        nil
    end
  end

  defp date_to_string(%Date{} = date) do
    Calendar.strftime(date, "%Y-%m-%d")
  end

  defp date_to_naive_datetime(%Date{} = date) do
    NaiveDateTime.new!(date, ~T[23:00:00])
  end

  defp storage_report_path(selected_basin, selected_date) do
    params = [date: date_to_string(selected_date)]

    params =
      if selected_basin == "__all__" do
        params
      else
        Keyword.put(params, :basin, selected_basin)
      end

    ~p"/dashboard/storage-report?#{params}"
  end

  defp storage_metric_label("__all__"), do: "Armazenamento nacional"
  defp storage_metric_label(_basin), do: "Armazenamento da bacia"

  defp attention_metric_label("__all__"), do: "Bacias em atenção"
  defp attention_metric_label(_basin), do: "Bacia em atenção"

  defp format_pct(nil), do: "n/d"
  defp format_pct(value), do: "#{format_number(value)}%"

  defp format_delta(nil), do: "n/d"
  defp format_delta(value) when value > 0, do: "+#{format_number(value)} p.p."
  defp format_delta(value), do: "#{format_number(value)} p.p."

  defp delta_text(nil, label), do: "Sem dados #{label}"
  defp delta_text(value, label), do: "#{format_delta(value)} #{label}"

  defp format_volume(nil), do: "n/d"
  defp format_volume(value), do: "#{format_number(value)} hm³"

  defp format_number(value) when is_number(value) do
    :erlang.float_to_binary(value * 1.0, decimals: 1)
  end

  defp format_datetime(nil), do: "n/d"

  defp format_datetime(%NaiveDateTime{} = value) do
    Calendar.strftime(value, "%d/%m/%Y %H:%M")
  end

  defp bar_width(nil), do: 0
  defp bar_width(value), do: value |> max(0) |> min(100)

  defp status_label(:good), do: "acima de 70%"
  defp status_label(:normal), do: "entre 50% e 70%"
  defp status_label(:low), do: "abaixo de 50%"
  defp status_label(:alert), do: "em atenção"
  defp status_label(_), do: "sem dados"

  defp delta_class(nil), do: "text-slate-500 dark:text-slate-400"
  defp delta_class(value) when value > 0, do: "text-emerald-600 dark:text-emerald-400"
  defp delta_class(value) when value < 0, do: "text-rose-600 dark:text-rose-400"
  defp delta_class(_), do: "text-slate-500 dark:text-slate-400"

  defp accent_bg("sky"), do: "bg-sky-500"
  defp accent_bg("teal"), do: "bg-teal-500"
  defp accent_bg("amber"), do: "bg-amber-500"
  defp accent_bg(_), do: "bg-brand-600"

  defp basin_map_image(%{basins: basins}) do
    stats_by_basin =
      Map.new(basins, fn basin ->
        {normalize_basin_name(basin.name), basin}
      end)

    svg =
      """
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 260 500" role="img">
        <rect width="260" height="500" rx="18" fill="#f8fafc"/>
        <g>
          #{hydro_feature_paths(stats_by_basin)}
        </g>
      </svg>
      """

    "data:image/svg+xml;base64," <> Base.encode64(svg)
  end

  defp mini_basin_map_image(basin) do
    with %{} = feature <- hydro_feature_for(basin.name),
         %{} = bounds <- feature["geometry"] |> geometry_bounds() |> expand_bounds(0.18) do
      selected_name = normalize_basin_name(basin.name)

      path =
        geometry_to_svg_path(feature["geometry"], fn lon, lat ->
          basin_svg_point(lon, lat, bounds)
        end)

      context_paths = mini_context_feature_paths(selected_name, bounds)
      fill = storage_color(basin.current_pct)
      markers = basin_dam_markers(basin, bounds)

      svg =
        """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 220" role="img">
          <rect width="220" height="220" rx="10" fill="#ffffff"/>
          #{context_paths}
          <path d="#{path}" fill="#{fill}" fill-opacity="0.84" fill-rule="evenodd" stroke="#0f172a" stroke-opacity="0.36" stroke-width="1.4"/>
          #{markers}
        </svg>
        """

      "data:image/svg+xml;base64," <> Base.encode64(svg)
    else
      _ -> mini_basin_fallback_image(basin)
    end
  end

  defp mini_context_feature_paths(selected_name, bounds) do
    hydro_features()
    |> Enum.reject(fn feature ->
      feature
      |> get_in(["properties", "zname"])
      |> normalize_basin_name() == selected_name
    end)
    |> Enum.filter(fn feature ->
      feature["geometry"]
      |> geometry_bounds()
      |> bounds_intersect?(bounds)
    end)
    |> Enum.map(fn feature ->
      path =
        geometry_to_svg_path(feature["geometry"], fn lon, lat ->
          basin_svg_point(lon, lat, bounds)
        end)

      """
      <path d="#{path}" fill="#cbd5e1" fill-opacity="0.30" fill-rule="evenodd" stroke="#ffffff" stroke-opacity="0.8" stroke-width="0.9"/>
      """
    end)
    |> Enum.join("\n")
  end

  defp hydro_feature_paths(stats_by_basin) do
    hydro_features()
    |> Enum.map(fn feature ->
      zname = get_in(feature, ["properties", "zname"])
      basin = Map.get(stats_by_basin, normalize_basin_name(zname))
      fill = if basin, do: storage_color(basin.current_pct), else: "#cbd5e1"
      opacity = if basin, do: "0.92", else: "0.45"
      title = Phoenix.HTML.html_escape(zname || "Bacia sem nome") |> Phoenix.HTML.safe_to_string()
      path = geometry_to_svg_path(feature["geometry"])

      """
      <path d="#{path}" fill="#{fill}" fill-opacity="#{opacity}" fill-rule="evenodd" stroke="#ffffff" stroke-width="0.8">
        <title>#{title}</title>
      </path>
      """
    end)
    |> Enum.join("\n")
  end

  defp hydro_feature_for(basin_name) do
    normalized = normalize_basin_name(basin_name)

    Enum.find(hydro_features(), fn feature ->
      feature
      |> get_in(["properties", "zname"])
      |> normalize_basin_name() == normalized
    end)
  end

  defp hydro_features do
    hydro_geojson_path()
    |> File.read!()
    |> Jason.decode!()
    |> Map.fetch!("features")
  end

  defp hydro_geojson_path do
    case :code.priv_dir(:barragenspt) do
      {:error, _reason} ->
        @hydro_geojson_source_path

      priv_dir ->
        priv_dir
        |> to_string()
        |> Path.join("static/geojson/pt100_hidro.json")
    end
  end

  defp geometry_to_svg_path(geometry) do
    geometry_to_svg_path(geometry, &portugal_svg_point/2)
  end

  defp geometry_to_svg_path(%{"type" => "MultiPolygon", "coordinates" => polygons}, project_point) do
    polygons
    |> Enum.map(&polygon_to_svg_path(&1, project_point))
    |> Enum.join(" ")
  end

  defp geometry_to_svg_path(%{"type" => "Polygon", "coordinates" => rings}, project_point) do
    polygon_to_svg_path(rings, project_point)
  end

  defp geometry_to_svg_path(_geometry, _project_point), do: ""

  defp polygon_to_svg_path(rings, project_point) do
    rings
    |> Enum.map(fn ring ->
      ring
      |> Enum.with_index()
      |> Enum.map(fn {[lon, lat | _], index} ->
        {x, y} = project_point.(lon, lat)
        command = if index == 0, do: "M", else: "L"
        "#{command}#{format_svg_number(x)} #{format_svg_number(y)}"
      end)
      |> Kernel.++(["Z"])
      |> Enum.join(" ")
    end)
    |> Enum.join(" ")
  end

  defp portugal_svg_point(lon, lat) do
    x = scale(lon, @portugal_bounds.min_lon, @portugal_bounds.max_lon, 18, 242)
    y = scale(lat, @portugal_bounds.max_lat, @portugal_bounds.min_lat, 16, 484)
    {x, y}
  end

  defp basin_svg_point(lon, lat, bounds) do
    padding = 12
    canvas = 220
    drawable = canvas - padding * 2
    lon_span = max(bounds.max_lon - bounds.min_lon, 0.0001)
    lat_span = max(bounds.max_lat - bounds.min_lat, 0.0001)
    factor = min(drawable / lon_span, drawable / lat_span)
    width = lon_span * factor
    height = lat_span * factor
    offset_x = (canvas - width) / 2
    offset_y = (canvas - height) / 2

    {offset_x + (lon - bounds.min_lon) * factor, offset_y + (bounds.max_lat - lat) * factor}
  end

  defp geometry_bounds(geometry) do
    case geometry_points(geometry) do
      [] ->
        nil

      points ->
        lons = Enum.map(points, &elem(&1, 0))
        lats = Enum.map(points, &elem(&1, 1))

        %{
          min_lon: Enum.min(lons),
          max_lon: Enum.max(lons),
          min_lat: Enum.min(lats),
          max_lat: Enum.max(lats)
        }
    end
  end

  defp expand_bounds(nil, _ratio), do: nil

  defp expand_bounds(bounds, ratio) do
    lon_pad = max((bounds.max_lon - bounds.min_lon) * ratio, 0.03)
    lat_pad = max((bounds.max_lat - bounds.min_lat) * ratio, 0.03)

    %{
      min_lon: bounds.min_lon - lon_pad,
      max_lon: bounds.max_lon + lon_pad,
      min_lat: bounds.min_lat - lat_pad,
      max_lat: bounds.max_lat + lat_pad
    }
  end

  defp bounds_intersect?(nil, _bounds), do: false

  defp bounds_intersect?(a, b) do
    not (a.max_lon < b.min_lon or a.min_lon > b.max_lon or a.max_lat < b.min_lat or
           a.min_lat > b.max_lat)
  end

  defp geometry_points(%{"type" => "MultiPolygon", "coordinates" => polygons}) do
    for polygon <- polygons, ring <- polygon, [lon, lat | _] <- ring, do: {lon, lat}
  end

  defp geometry_points(%{"type" => "Polygon", "coordinates" => rings}) do
    for ring <- rings, [lon, lat | _] <- ring, do: {lon, lat}
  end

  defp geometry_points(_geometry), do: []

  defp basin_dam_markers(basin, bounds) do
    basin.dams
    |> Enum.map(fn dam ->
      case dam.coordinates do
        %{lat: lat, lon: lon} ->
          {x, y} = basin_svg_point(lon, lat, bounds)
          name = Phoenix.HTML.html_escape(dam.name || "Barragem") |> Phoenix.HTML.safe_to_string()

          """
          <circle cx="#{format_svg_number(x)}" cy="#{format_svg_number(y)}" r="4.5" fill="#0f172a" stroke="#ffffff" stroke-width="2">
            <title>#{name}</title>
          </circle>
          """

        _ ->
          ""
      end
    end)
    |> Enum.join("\n")
  end

  defp mini_basin_fallback_image(basin) do
    fill = storage_color(basin.current_pct)

    svg =
      """
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 220" role="img">
        <rect width="220" height="220" rx="10" fill="#ffffff"/>
        <path d="M72 24 C112 16 169 37 185 80 C205 134 167 190 114 197 C66 204 31 169 27 119 C24 78 40 40 72 24 Z" fill="#{fill}" fill-opacity="0.72"/>
      </svg>
      """

    "data:image/svg+xml;base64," <> Base.encode64(svg)
  end

  defp format_svg_number(value) when is_number(value) do
    :erlang.float_to_binary(value * 1.0, decimals: 2)
  end

  defp storage_color(value) when is_number(value) and value <= 20, do: "#ff675c"
  defp storage_color(value) when is_number(value) and value <= 40, do: "#ffc34a"
  defp storage_color(value) when is_number(value) and value <= 50, do: "#ffe99c"
  defp storage_color(value) when is_number(value) and value <= 60, do: "#c2faaa"
  defp storage_color(value) when is_number(value) and value <= 80, do: "#a6d8ff"
  defp storage_color(value) when is_number(value) and value <= 100, do: "#1c9dff"
  defp storage_color(_value), do: "#94a3b8"

  defp normalize_basin_name(nil), do: ""

  defp normalize_basin_name(name) do
    name
    |> String.downcase()
    |> String.normalize(:nfd)
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
