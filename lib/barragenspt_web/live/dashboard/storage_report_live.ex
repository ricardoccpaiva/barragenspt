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
    {:ok,
     socket
     |> assign(:page_title, "Relatório de armazenamento")
     |> assign(:basin_options, StorageReport.list_basins())
     |> assign(:selected_basin, "__all__")
     |> assign(:loading_report, false)
     |> assign(:basin_map_image, nil)
     |> assign(:report, nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    selected_basin = selected_basin_param(Map.get(params, "basin"))

    {:noreply,
     socket
     |> assign(:selected_basin, selected_basin)
     |> assign(:loading_report, false)
     |> assign(:basin_map_image, nil)
     |> assign(:report, nil)}
  end

  @impl true
  def handle_event("generate_report", _params, socket) do
    send(self(), {:generate_storage_report, socket.assigns.selected_basin})

    {:noreply,
     socket
     |> assign(:loading_report, true)
     |> assign(:basin_map_image, nil)
     |> assign(:report, nil)}
  end

  def handle_event("select_basin", %{"basin" => "__all__"}, socket) do
    {:noreply, push_patch(socket, to: ~p"/dashboard/storage-report")}
  end

  def handle_event("select_basin", %{"basin" => basin}, socket) do
    {:noreply, push_patch(socket, to: ~p"/dashboard/storage-report?basin=#{basin}")}
  end

  @impl true
  def handle_info({:generate_storage_report, selected_basin}, socket) do
    report = StorageReport.build(basin: selected_basin)

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
      <svg
        viewBox="0 0 220 220"
        role="img"
        aria-label={"Bacia do #{@basin.name} com pontos das barragens"}
      >
        <rect
          x="0"
          y="0"
          width="220"
          height="220"
          rx="10"
          fill="currentColor"
          class="text-white dark:text-slate-800"
        />
        <path
          d="M72 24 C112 16 169 37 185 80 C205 134 167 190 114 197 C66 204 31 169 27 119 C24 78 40 40 72 24 Z"
          fill={status_color(@basin.status)}
          opacity="0.64"
        />
        <path
          d="M49 56 C79 82 95 91 104 118 C115 151 144 164 174 184"
          fill="none"
          stroke="#0284c7"
          stroke-opacity="0.38"
          stroke-width="3"
          stroke-linecap="round"
        />
        <path
          d="M142 42 C129 73 131 99 104 118"
          fill="none"
          stroke="#0284c7"
          stroke-opacity="0.32"
          stroke-width="3"
          stroke-linecap="round"
        />
        <%= for {dam, index} <- Enum.with_index(@basin.dams) do %>
          <% {x, y} = mini_map_point(@basin, dam, index) %>
          <g>
            <circle cx={x} cy={y} r="5" fill="#0f172a" stroke="#ffffff" stroke-width="2" />
            <text
              x={x + 8}
              y={label_y(y)}
              class="fill-slate-700 text-[8px] font-semibold dark:fill-slate-200"
            >
              {truncate(dam.name, 18)}
            </text>
          </g>
        <% end %>
      </svg>
    </aside>
    """
  end

  defp mini_map_point(basin, %{coordinates: %{lat: lat, lon: lon}}, _index) do
    coords =
      basin.dams
      |> Enum.map(& &1.coordinates)
      |> Enum.reject(&is_nil/1)

    lats = Enum.map(coords, & &1.lat)
    lons = Enum.map(coords, & &1.lon)

    {scale(lon, Enum.min(lons), Enum.max(lons), 42, 178),
     scale(lat, Enum.max(lats), Enum.min(lats), 42, 178)}
  end

  defp mini_map_point(_basin, _dam, index) do
    {56 + rem(index * 47, 110), 60 + rem(index * 59, 100)}
  end

  defp scale(_value, same, same, min_out, max_out), do: (min_out + max_out) / 2

  defp scale(value, min_in, max_in, min_out, max_out) do
    min_out + (value - min_in) / (max_in - min_in) * (max_out - min_out)
  end

  defp label_y(y) when y > 150, do: y - 9
  defp label_y(y), do: y + 15

  defp selected_basin_param(nil), do: "__all__"
  defp selected_basin_param(""), do: "__all__"
  defp selected_basin_param("__all__"), do: "__all__"
  defp selected_basin_param(basin), do: basin

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

  defp status_color(:good), do: "#5eead4"
  defp status_color(:normal), do: "#7dd3fc"
  defp status_color(:low), do: "#fbbf24"
  defp status_color(:alert), do: "#f87171"
  defp status_color(_), do: "#cbd5e1"

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

  defp geometry_to_svg_path(%{"type" => "MultiPolygon", "coordinates" => polygons}) do
    polygons
    |> Enum.map(&polygon_to_svg_path/1)
    |> Enum.join(" ")
  end

  defp geometry_to_svg_path(%{"type" => "Polygon", "coordinates" => rings}) do
    polygon_to_svg_path(rings)
  end

  defp geometry_to_svg_path(_geometry), do: ""

  defp polygon_to_svg_path(rings) do
    rings
    |> Enum.map(fn ring ->
      ring
      |> Enum.with_index()
      |> Enum.map(fn {[lon, lat | _], index} ->
        {x, y} = portugal_svg_point(lon, lat)
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

  defp truncate(nil, _max), do: ""

  defp truncate(text, max) do
    if String.length(text) <= max do
      text
    else
      String.slice(text, 0, max - 3) <> "..."
    end
  end
end
