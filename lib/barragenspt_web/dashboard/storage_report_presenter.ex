defmodule BarragensptWeb.Dashboard.StorageReportPresenter do
  @moduledoc """
  Shared storage report presentation helpers for LiveView and PDF exports.
  """

  use BarragensptWeb, :verified_routes

  alias Barragenspt.Hydrometrics.{MonthlyStorageReport, StorageReport}

  @dam3_per_hm3 1000
  @hydro_geojson_source_path Path.expand("../../../priv/static/geojson/pt100_hidro.json", __DIR__)
  @portugal_bounds %{min_lon: -9.7, max_lon: -6.1, min_lat: 36.8, max_lat: 42.2}

  def params_from_request(params, defaults \\ %{}) do
    month_bounds =
      Map.get(defaults, :month_bounds) || MonthlyStorageReport.selectable_month_bounds()

    fallback_date = Map.get(defaults, :selected_date) || current_week_monday()
    fallback_month = Map.get(defaults, :selected_month) || month_bounds.max

    report_type = selected_report_type_param(Map.get(params, "report_type"))

    %{
      report_type: report_type,
      selected_basin: selected_basin_param(Map.get(params, "basin")),
      selected_date: parse_basin_date_param(Map.get(params, "date"), fallback_date),
      selected_month: parse_month_param(Map.get(params, "month"), fallback_month, month_bounds),
      month_bounds: month_bounds
    }
  end

  def current_week_monday do
    today = Timex.now("Europe/Lisbon") |> Timex.to_date()
    Date.add(today, 1 - Date.day_of_week(today))
  end

  def build_report("monthly", selected_basin, _selected_date, selected_month) do
    MonthlyStorageReport.build(
      basin: selected_basin,
      report_month: selected_month
    )
  end

  def build_report(_report_type, selected_basin, selected_date, _selected_month) do
    StorageReport.build(
      basin: selected_basin,
      reference_at: date_to_naive_datetime(selected_date)
    )
  end

  def storage_report_path(report_type, selected_basin, selected_date, selected_month) do
    ~p"/dashboard/storage-report?#{storage_report_params(report_type, selected_basin, selected_date, selected_month)}"
  end

  def pdf_export_path(report_type, selected_basin, selected_date, selected_month) do
    ~p"/dashboard/storage-report/export/pdf?#{storage_report_params(report_type, selected_basin, selected_date, selected_month)}"
  end

  def filename("monthly", %{report_month: %Date{} = month}) do
    "relatorio-armazenamento-mensal-#{month_to_string(month)}.pdf"
  end

  def filename(_report_type, %{report_date: %NaiveDateTime{} = date}) do
    "relatorio-armazenamento-semanal-#{date |> NaiveDateTime.to_date() |> date_to_string()}.pdf"
  end

  def filename(report_type, _report), do: "relatorio-armazenamento-#{report_type}.pdf"

  def report_title("monthly"), do: "Relatório mensal de armazenamento"
  def report_title(_), do: "Relatório semanal de armazenamento"

  def report_reference(%{report_month: month}, "monthly"), do: month_label(month)
  def report_reference(%{report_date: dt}, _), do: format_datetime(dt)

  def period_delta(summary, "monthly"), do: Map.get(summary, :month_delta)
  def period_delta(summary, _), do: Map.get(summary, :week_delta)

  def period_delta_from(item, "monthly"), do: Map.get(item, :month_delta)
  def period_delta_from(item, _), do: Map.get(item, :week_delta)

  def period_header("monthly"), do: "Mês"
  def period_header(_), do: "Semana"

  def period_subtitle("monthly"), do: "vs mês anterior"
  def period_subtitle(_), do: "vs semana anterior"

  def reference_subtitle("monthly"), do: "Mesmo mês, anos anteriores"
  def reference_subtitle(_), do: "Mesma semana ISO, anos anteriores"

  def storage_metric_label("__all__"), do: "Armazenamento nacional"
  def storage_metric_label(_basin), do: "Armazenamento da bacia"

  def attention_metric_label("__all__"), do: "Bacias em atenção"
  def attention_metric_label(_basin), do: "Bacia em atenção"

  def status_label(:good), do: "acima de 70%"
  def status_label(:normal), do: "entre 50% e 70%"
  def status_label(:low), do: "abaixo de 50%"
  def status_label(:alert), do: "em atenção"
  def status_label(_), do: "sem dados"

  def format_river(nil), do: "Rio n/d"

  def format_river(value) when is_binary(value) do
    river =
      value
      |> String.trim()
      |> String.downcase()
      |> String.split(~r/\s+/, trim: true)
      |> Enum.map_join(" ", &capitalize_word/1)

    cond do
      river == "" -> "Rio n/d"
      String.match?(river, ~r/^Rio\b/u) -> river
      true -> "Rio #{river}"
    end
  end

  def format_river(_), do: "Rio n/d"

  def format_pct(nil), do: "n/d"
  def format_pct(value), do: "#{format_number(value)}%"

  def format_delta(nil), do: "n/d"
  def format_delta(value) when value > 0, do: "+#{format_number(value)} %"
  def format_delta(value), do: "#{format_number(value)} %"

  def delta_text(nil, label), do: "Sem dados #{label}"
  def delta_text(value, label), do: "#{format_delta(value)} #{label}"

  def format_volume(nil), do: "n/d"
  def format_volume(value), do: "#{format_number(value / @dam3_per_hm3)} hm³"

  def format_datetime(nil), do: "n/d"

  def format_datetime(%NaiveDateTime{} = value) do
    Calendar.strftime(value, "%d/%m/%Y %H:%M")
  end

  def date_to_string(%Date{} = date), do: Calendar.strftime(date, "%Y-%m-%d")
  def month_to_string(%Date{} = date), do: Calendar.strftime(date, "%Y-%m")

  def month_label(%Date{} = date) do
    months = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"]
    "#{Enum.at(months, date.month - 1)} #{date.year}"
  end

  def delta_class(nil), do: "delta-neutral"
  def delta_class(value) when value > 0, do: "delta-positive"
  def delta_class(value) when value < 0, do: "delta-negative"
  def delta_class(_), do: "delta-neutral"

  def storage_color(value) when is_number(value) and value <= 20, do: "#ff675c"
  def storage_color(value) when is_number(value) and value <= 40, do: "#ffc34a"
  def storage_color(value) when is_number(value) and value <= 50, do: "#ffe99c"
  def storage_color(value) when is_number(value) and value <= 60, do: "#c2faaa"
  def storage_color(value) when is_number(value) and value <= 80, do: "#a6d8ff"
  def storage_color(value) when is_number(value) and value <= 100, do: "#1c9dff"
  def storage_color(_value), do: "#94a3b8"

  def storage_bucket_color(:pct_0_20), do: "#ff675c"
  def storage_bucket_color(:pct_21_40), do: "#ffc34a"
  def storage_bucket_color(:pct_41_50), do: "#ffe99c"
  def storage_bucket_color(:pct_51_60), do: "#c2faaa"
  def storage_bucket_color(:pct_61_80), do: "#a6d8ff"
  def storage_bucket_color(:pct_81_100), do: "#1c9dff"
  def storage_bucket_color(_), do: "#94a3b8"

  def storage_bucket_label(%{key: :unknown, label: label}), do: label
  def storage_bucket_label(%{label: label}), do: "#{label}%"

  def extreme_dam_name(nil), do: "n/d"
  def extreme_dam_name(%{name: name}) when is_binary(name), do: name
  def extreme_dam_name(_), do: "n/d"

  def extreme_dam_detail(nil), do: "Sem dados"

  def extreme_dam_detail(%{current_pct: pct, basin: basin}) do
    [format_pct(pct), basin]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  def report_map_svg(%{basins: basins}) do
    dams = Enum.flat_map(basins, & &1.dams)

    stats_by_basin =
      Map.new(basins, fn basin ->
        {basin_lookup_key(basin.name), basin}
      end)

    feature_styles =
      Map.new(hydro_features(), fn feature ->
        zname = get_in(feature, ["properties", "zname"])
        basin = Map.get(stats_by_basin, basin_lookup_key(zname))

        {zname,
         %{
           fill: if(basin, do: storage_color(basin.current_pct), else: "#cbd5e1"),
           opacity: if(basin, do: "0.90", else: "0.38"),
           stroke: "#ffffff",
           stroke_width: "1.1"
         }}
      end)

    basin_svg(
      hydro_features(),
      dams,
      @portugal_bounds,
      "Portugal continental",
      480,
      560,
      feature_styles
    )
  end

  def basin_map_svg(%{dams: dams, name: name}) do
    case hydro_feature_for(name) do
      %{} = feature ->
        bounds =
          feature
          |> Map.get("geometry")
          |> geometry_bounds()
          |> expand_bounds(0.18)

        styles = %{
          get_in(feature, ["properties", "zname"]) => %{
            fill: dams |> basin_pct() |> storage_color(),
            opacity: "0.88",
            stroke: "#0284c7",
            stroke_width: "1.6"
          }
        }

        basin_svg([feature], dams, bounds, "Bacia #{name}", 260, 180, styles)

      _ ->
        bounds =
          dams
          |> dam_bounds()
          |> expand_bounds(0.18)

        basin_svg([], dams, bounds, "Bacia #{name}", 260, 180, %{})
    end
  end

  defp basin_svg(features, dams, bounds, label, width, height, feature_styles) do
    projection = projection_context(bounds, width, height)

    paths =
      features
      |> Enum.map(fn feature ->
        name = get_in(feature, ["properties", "zname"])
        style = Map.get(feature_styles, name, default_feature_style())

        ~s(<path d="#{geometry_path(feature["geometry"], projection)}" fill="#{style.fill}" fill-opacity="#{style.opacity}" stroke="#{style.stroke}" stroke-width="#{style.stroke_width}"><title>#{escape(name)}</title></path>)
      end)
      |> Enum.join("")

    points =
      dams
      |> Enum.filter(&valid_coordinates?/1)
      |> Enum.map(fn dam ->
        %{lat: lat, lon: lon} = dam.coordinates
        {x, y} = project(lon, lat, projection)

        ~s(<circle cx="#{x}" cy="#{y}" r="5" fill="#{storage_color(dam.current_pct)}" stroke="#ffffff" stroke-width="1.5"><title>#{escape(dam.name)} - #{format_pct(dam.current_pct)}</title></circle>)
      end)
      |> Enum.join("")

    empty =
      if points == "" and paths == "" do
        ~s(<text x="50%" y="50%" text-anchor="middle" fill="#64748b" font-size="12">Sem coordenadas disponíveis</text>)
      else
        ""
      end

    """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{width} #{height}" role="img" aria-label="#{escape(label)}">
      <rect width="100%" height="100%" rx="18" fill="#f8fafc"/>
      <rect x="10" y="10" width="#{width - 20}" height="#{height - 20}" rx="14" fill="#eef6fb" stroke="#cbd5e1"/>
      #{paths}
      #{points}
      #{empty}
    </svg>
    """
  end

  defp default_feature_style do
    %{fill: "#dbeafe", opacity: "0.62", stroke: "#ffffff", stroke_width: "1"}
  end

  defp basin_pct(dams) do
    capacity = sum(dams, :total_capacity)
    current_volume = sum(dams, :current_volume)

    case {current_volume, capacity} do
      {volume, capacity} when is_number(volume) and is_number(capacity) and capacity > 0 ->
        volume / capacity * 100

      _ ->
        nil
    end
  end

  defp dam_bounds(dams) do
    coords =
      dams
      |> Enum.filter(&valid_coordinates?/1)
      |> Enum.map(& &1.coordinates)

    if coords == [] do
      @portugal_bounds
    else
      %{
        min_lon: coords |> Enum.map(& &1.lon) |> Enum.min(),
        max_lon: coords |> Enum.map(& &1.lon) |> Enum.max(),
        min_lat: coords |> Enum.map(& &1.lat) |> Enum.min(),
        max_lat: coords |> Enum.map(& &1.lat) |> Enum.max()
      }
    end
  end

  defp expand_bounds(bounds, ratio) do
    lon_pad = max((bounds.max_lon - bounds.min_lon) * ratio, 0.08)
    lat_pad = max((bounds.max_lat - bounds.min_lat) * ratio, 0.08)

    %{
      min_lon: bounds.min_lon - lon_pad,
      max_lon: bounds.max_lon + lon_pad,
      min_lat: bounds.min_lat - lat_pad,
      max_lat: bounds.max_lat + lat_pad
    }
  end

  defp valid_coordinates?(%{coordinates: %{lat: lat, lon: lon}}),
    do: is_number(lat) and is_number(lon)

  defp valid_coordinates?(_), do: false

  defp projection_context(bounds, width, height) do
    pad = 26

    # Longitude degrees get visually wider than their real distance at Portugal's latitude.
    # Project them with a cosine correction, then use one uniform scale for both axes.
    lat_mid = (bounds.min_lat + bounds.max_lat) / 2
    lon_factor = :math.cos(lat_mid * :math.pi() / 180)

    min_x = bounds.min_lon * lon_factor
    max_x = bounds.max_lon * lon_factor
    min_y = bounds.min_lat
    max_y = bounds.max_lat

    projected_width = max(max_x - min_x, 0.0001)
    projected_height = max(max_y - min_y, 0.0001)
    available_width = width - pad * 2
    available_height = height - pad * 2
    scale = min(available_width / projected_width, available_height / projected_height)

    drawing_width = projected_width * scale
    drawing_height = projected_height * scale

    %{
      lon_factor: lon_factor,
      min_x: min_x,
      max_y: max_y,
      scale: scale,
      offset_x: pad + (available_width - drawing_width) / 2,
      offset_y: pad + (available_height - drawing_height) / 2
    }
  end

  defp project(lon, lat, projection) do
    x = projection.offset_x + (lon * projection.lon_factor - projection.min_x) * projection.scale
    y = projection.offset_y + (projection.max_y - lat) * projection.scale

    {Float.round(x, 1), Float.round(y, 1)}
  end

  defp hydro_feature_for(basin_name) do
    normalized = basin_lookup_key(basin_name)

    Enum.find(hydro_features(), fn feature ->
      feature
      |> get_in(["properties", "zname"])
      |> basin_lookup_key() == normalized
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

  defp geometry_bounds(geometry) do
    case geometry_points(geometry) do
      [] ->
        @portugal_bounds

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

  defp geometry_points(%{"type" => "MultiPolygon", "coordinates" => polygons}) do
    for polygon <- polygons, ring <- polygon, [lon, lat | _] <- ring, do: {lon, lat}
  end

  defp geometry_points(%{"type" => "Polygon", "coordinates" => rings}) do
    for ring <- rings, [lon, lat | _] <- ring, do: {lon, lat}
  end

  defp geometry_points(_geometry), do: []

  defp geometry_path(%{"type" => "MultiPolygon", "coordinates" => polygons}, projection) do
    polygons
    |> Enum.flat_map(& &1)
    |> Enum.map_join(" ", &ring_path(&1, projection))
  end

  defp geometry_path(%{"type" => "Polygon", "coordinates" => rings}, projection) do
    Enum.map_join(rings, " ", &ring_path(&1, projection))
  end

  defp geometry_path(_geometry, _projection), do: ""

  defp ring_path(ring, projection) do
    ring
    |> Enum.map(fn [lon, lat | _] ->
      {x, y} = project(lon, lat, projection)
      "#{x},#{y}"
    end)
    |> case do
      [] -> ""
      [first | rest] -> "M #{first} " <> Enum.map_join(rest, " ", &"L #{&1}") <> " Z"
    end
  end

  defp storage_report_params(report_type, selected_basin, selected_date, selected_month) do
    params =
      case report_type do
        "monthly" -> [report_type: "monthly", month: month_to_string(selected_month)]
        _ -> [report_type: "weekly", date: date_to_string(selected_date)]
      end

    if selected_basin == "__all__", do: params, else: Keyword.put(params, :basin, selected_basin)
  end

  defp selected_report_type_param("monthly"), do: "monthly"
  defp selected_report_type_param(_), do: "weekly"

  defp selected_basin_param(nil), do: "__all__"
  defp selected_basin_param(""), do: "__all__"
  defp selected_basin_param("__all__"), do: "__all__"
  defp selected_basin_param(basin), do: basin

  defp parse_basin_date_param(nil, fallback), do: fallback
  defp parse_basin_date_param("", fallback), do: fallback

  defp parse_basin_date_param(date_string, fallback) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> if Date.day_of_week(date) == 1, do: date, else: fallback
      _ -> fallback
    end
  end

  defp parse_month_param(nil, fallback, _bounds), do: fallback
  defp parse_month_param("", fallback, _bounds), do: fallback

  defp parse_month_param(month_string, fallback, bounds) do
    case String.split(month_string, "-", parts: 2) do
      [year, month] ->
        with {year_int, ""} <- Integer.parse(year),
             {month_int, ""} <- Integer.parse(month),
             true <- month_int >= 1 and month_int <= 12 do
          month_date = Date.new!(year_int, month_int, 1)

          cond do
            Date.compare(month_date, bounds.min) == :lt -> bounds.min
            Date.compare(month_date, bounds.max) == :gt -> bounds.max
            true -> month_date
          end
        else
          _ -> fallback
        end

      _ ->
        fallback
    end
  end

  defp date_to_naive_datetime(%Date{} = date), do: NaiveDateTime.new!(date, ~T[23:00:00])

  defp format_number(value) when is_number(value) do
    :erlang.float_to_binary(value * 1.0, decimals: 1)
  end

  defp sum(items, key) do
    values =
      items
      |> Enum.map(&Map.get(&1, key))
      |> Enum.reject(&is_nil/1)

    if values == [], do: nil, else: Enum.sum(values)
  end

  defp normalize_basin_name(nil), do: ""

  defp normalize_basin_name(name) do
    name
    |> String.downcase()
    |> String.normalize(:nfd)
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp basin_lookup_key(name) do
    key =
      name
      |> normalize_basin_name()
      |> String.replace(~r/[^a-z0-9]+/u, " ")
      |> String.split(" ", trim: true)
      |> Enum.reject(&(&1 in ~w(e de do da dos das)))
      |> Enum.join(" ")

    case key do
      "vouga" -> "vouga ribeiras costeiras"
      other -> other
    end
  end

  defp escape(value) do
    value
    |> to_string()
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  defp capitalize_word(<<first::binary-size(1), rest::binary>>) do
    String.upcase(first) <> rest
  end

  defp capitalize_word(""), do: ""
end
