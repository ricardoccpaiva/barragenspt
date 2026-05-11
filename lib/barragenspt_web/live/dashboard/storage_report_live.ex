defmodule BarragensptWeb.Dashboard.StorageReportLive do
  use BarragensptWeb, :live_view

  on_mount {BarragensptWeb.UserAuth, :require_authenticated}

  alias Barragenspt.Hydrometrics.{
    MonthlyStorageReport,
    MonthlyStorageReportAi,
    StorageReport,
    StorageReportAi
  }

  alias BarragensptWeb.Dashboard.StorageReportPresenter
  alias BarragensptWeb.StorageReportComponents

  @dam3_per_hm3 1000
  @hydro_geojson_source_path Path.expand(
                               "../../../../priv/static/geojson/pt100_hidro.json",
                               __DIR__
                             )
  @external_resource @hydro_geojson_source_path
  @portugal_bounds %{min_lon: -9.7, max_lon: -6.1, min_lat: 36.8, max_lat: 42.2}

  @impl true
  def mount(_params, _session, socket) do
    default_date = current_week_monday()
    month_bounds = MonthlyStorageReport.selectable_month_bounds()

    {:ok,
     socket
     |> assign(:page_title, "Relatório de armazenamento")
     |> assign(:basin_options, StorageReport.list_basins())
     |> assign(:report_type, "weekly")
     |> assign(:selected_basin, "__all__")
     |> assign(:selected_date, default_date)
     |> assign(:selected_month, month_bounds.max)
     |> assign(:month_bounds, month_bounds)
     |> assign(:loading_report, false)
     |> assign(:loading_ai_summary, false)
     |> assign(:ai_summary, nil)
     |> assign(:ai_error, nil)
     |> assign(:ai_gen, 0)
     |> assign(:ai_drawer_open, false)
     |> assign(:methodology_drawer_open, false)
     |> assign(:open_ai_summary_when_ready, false)
     |> assign(:cerebras_configured, StorageReportAi.configured?())
     |> assign(:portugal_map_payload, nil)
     |> assign(:report, nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    report_type = selected_report_type_param(Map.get(params, "report_type"))
    selected_basin = selected_basin_param(Map.get(params, "basin"))

    selected_date =
      parse_basin_date_param(Map.get(params, "date"), socket.assigns.selected_date)

    selected_month =
      parse_month_param(
        Map.get(params, "month"),
        socket.assigns.month_bounds.max,
        socket.assigns.month_bounds
      )

    {:noreply,
     socket
     |> assign(:report_type, report_type)
     |> assign(:selected_date, selected_date)
     |> assign(:selected_month, selected_month)
     |> assign(:selected_basin, selected_basin)
     |> assign(:cerebras_configured, ai_configured?(report_type))
     |> assign(:loading_report, false)
     |> assign(:loading_ai_summary, false)
     |> assign(:ai_summary, nil)
     |> assign(:ai_error, nil)
     |> assign(:ai_drawer_open, false)
     |> assign(:methodology_drawer_open, false)
     |> assign(:open_ai_summary_when_ready, false)
     |> assign(:portugal_map_payload, nil)
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
           to:
             storage_report_path(
               socket.assigns.report_type,
               socket.assigns.selected_basin,
               parsed_date,
               socket.assigns.selected_month
             )
         )}
    end
  end

  def handle_event("select_month", %{"month" => month}, socket) do
    month = parse_month_param(month, socket.assigns.selected_month, socket.assigns.month_bounds)

    {:noreply,
     push_patch(
       socket,
       to:
         storage_report_path(
           socket.assigns.report_type,
           socket.assigns.selected_basin,
           socket.assigns.selected_date,
           month
         )
     )}
  end

  def handle_event("select_report_type", %{"report_type" => report_type}, socket) do
    report_type = selected_report_type_param(report_type)

    {:noreply,
     push_patch(
       socket,
       to:
         storage_report_path(
           report_type,
           socket.assigns.selected_basin,
           socket.assigns.selected_date,
           socket.assigns.selected_month
         )
     )}
  end

  def handle_event("generate_report", _params, socket) do
    send(
      self(),
      {:generate_storage_report, socket.assigns.report_type, socket.assigns.selected_basin,
       socket.assigns.selected_date, socket.assigns.selected_month}
    )

    {:noreply,
     socket
     |> assign(:loading_report, true)
     |> assign(:loading_ai_summary, false)
     |> assign(:ai_summary, nil)
     |> assign(:ai_error, nil)
     |> assign(:ai_drawer_open, false)
     |> assign(:methodology_drawer_open, false)
     |> assign(:open_ai_summary_when_ready, false)
     |> assign(:portugal_map_payload, nil)
     |> assign(:report, nil)}
  end

  def handle_event("open_ai_summary", _params, %{assigns: %{report: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("open_ai_summary", _params, socket) do
    cond do
      not is_nil(socket.assigns.ai_summary) ->
        {:noreply, assign(socket, :ai_drawer_open, true)}

      socket.assigns.loading_ai_summary or not socket.assigns.cerebras_configured ->
        {:noreply, socket}

      true ->
        {:noreply,
         socket
         |> assign(:open_ai_summary_when_ready, true)
         |> start_ai_summary_generation()}
    end
  end

  def handle_event("generate_ai_summary", _params, %{assigns: %{report: nil}} = socket),
    do: {:noreply, socket}

  def handle_event("generate_ai_summary", _params, socket) do
    if socket.assigns.loading_ai_summary or not is_nil(socket.assigns.ai_summary) or
         not socket.assigns.cerebras_configured do
      {:noreply, socket}
    else
      {:noreply, start_ai_summary_generation(socket)}
    end
  end

  def handle_event("select_basin", %{"basin" => "__all__"}, socket) do
    {:noreply,
     push_patch(
       socket,
       to:
         storage_report_path(
           socket.assigns.report_type,
           "__all__",
           socket.assigns.selected_date,
           socket.assigns.selected_month
         )
     )}
  end

  def handle_event("select_basin", %{"basin" => basin}, socket) do
    {:noreply,
     push_patch(
       socket,
       to:
         storage_report_path(
           socket.assigns.report_type,
           basin,
           socket.assigns.selected_date,
           socket.assigns.selected_month
         )
     )}
  end

  def handle_event("close_ai_summary", _params, socket) do
    {:noreply,
     socket
     |> assign(:ai_drawer_open, false)
     |> assign(:open_ai_summary_when_ready, false)}
  end

  def handle_event("open_methodology", _params, socket) do
    {:noreply, assign(socket, :methodology_drawer_open, true)}
  end

  def handle_event("close_methodology", _params, socket) do
    {:noreply, assign(socket, :methodology_drawer_open, false)}
  end

  @impl true
  def handle_info(
        {:generate_storage_report, report_type, selected_basin, selected_date, selected_month},
        socket
      ) do
    report = build_report(report_type, selected_basin, selected_date, selected_month)

    {:noreply,
     socket
     |> assign(:loading_report, false)
     |> assign(:loading_ai_summary, false)
     |> assign(:ai_summary, nil)
     |> assign(:ai_error, nil)
     |> assign(:ai_drawer_open, false)
     |> assign(:methodology_drawer_open, false)
     |> assign(:open_ai_summary_when_ready, false)
     |> assign(:cerebras_configured, ai_configured?(report_type))
     |> assign(:portugal_map_payload, portugal_map_payload(report))
     |> assign(:report, report)}
  end

  @impl true
  def handle_info({:storage_report_ai_done, gen, result}, socket) do
    if gen != socket.assigns.ai_gen do
      {:noreply, socket}
    else
      case result do
        {:ok, summary} ->
          {:noreply,
           socket
           |> assign(:loading_ai_summary, false)
           |> assign(:ai_summary, summary)
           |> assign(:ai_error, nil)
           |> assign(:ai_drawer_open, socket.assigns.open_ai_summary_when_ready)
           |> assign(:open_ai_summary_when_ready, false)}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign(:loading_ai_summary, false)
           |> assign(:ai_summary, nil)
           |> assign(:ai_error, format_ai_error(reason))
           |> assign(:open_ai_summary_when_ready, false)}
      end
    end
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :sub, :string, required: true
  attr :accent, :string, default: "brand"

  defp metric_card(assigns) do
    ~H"""
    <div class="relative overflow-hidden rounded-2xl border border-slate-200 bg-white p-4 shadow-sm dark:border-slate-700 dark:bg-slate-800">
      <div class={["absolute inset-x-0 bottom-0 h-1 rounded-t-full", accent_bg(@accent)]}></div>
      <p class="text-xs font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400">
        {@label}
      </p>
      <p class="mt-2 text-2xl font-bold tabular-nums text-slate-950 dark:text-slate-50">{@value}</p>
      <p class="mt-2 text-sm text-slate-500 dark:text-slate-400">{@sub}</p>
    </div>
    """
  end

  attr :summary, :map, required: true

  defp storage_distribution_card(assigns) do
    ~H"""
    <div class="relative overflow-hidden rounded-2xl border border-slate-200 bg-white p-3 shadow-sm dark:border-slate-700 dark:bg-slate-800">
      <div class="absolute inset-x-0 bottom-0 h-1 rounded-t-full bg-amber-500"></div>
      <p class="text-xs font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400">
        Escalas e extremos
      </p>
      <div class="mt-2 grid grid-cols-3 gap-1.5">
        <%= for bucket <- @summary.storage_distribution do %>
          <span class="inline-flex min-w-0 items-center justify-between gap-1 rounded-md bg-slate-50 px-1.5 py-1 text-[0.68rem] font-semibold text-slate-700 dark:bg-slate-900/50 dark:text-slate-200">
            <span class="inline-flex min-w-0 items-center gap-1">
              <span
                class="h-2 w-2 shrink-0 rounded-full"
                style={"background-color: #{storage_bucket_color(bucket.key)}"}
              >
              </span>
              <span class="truncate">{storage_bucket_label(bucket)}</span>
            </span>
            <span class="tabular-nums text-slate-950 dark:text-slate-50">{bucket.count}</span>
          </span>
        <% end %>
      </div>
      <div class="mt-2 grid grid-cols-2 gap-2 text-xs">
        <.compact_extreme_dam label="Cheia" dam={@summary.fullest_dam} />
        <.compact_extreme_dam label="Vazia" dam={@summary.emptiest_dam} />
      </div>
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

  attr :label, :string, required: true
  attr :dam, :map, default: nil

  defp compact_extreme_dam(assigns) do
    ~H"""
    <div class="min-w-0">
      <span class="text-slate-500 dark:text-slate-400">{@label}</span>
      <%= if @dam do %>
        <p class="truncate font-semibold text-slate-950 dark:text-slate-50">{@dam.name}</p>
        <p class="tabular-nums text-slate-500 dark:text-slate-400">{format_pct(@dam.current_pct)}</p>
      <% else %>
        <p class="font-semibold text-slate-500 dark:text-slate-400">n/d</p>
      <% end %>
    </div>
    """
  end

  defp selected_basin_param(nil), do: "__all__"
  defp selected_basin_param(""), do: "__all__"
  defp selected_basin_param("__all__"), do: "__all__"
  defp selected_basin_param(basin), do: basin

  defp start_ai_summary_generation(socket) do
    gen = socket.assigns.ai_gen + 1
    report = socket.assigns.report
    report_type = socket.assigns.report_type
    parent = self()

    _ =
      Task.start(fn ->
        result =
          case report_type do
            "monthly" -> MonthlyStorageReportAi.summarize(report)
            _ -> StorageReportAi.summarize(report)
          end

        send(parent, {:storage_report_ai_done, gen, result})
      end)

    socket
    |> assign(:ai_gen, gen)
    |> assign(:loading_ai_summary, true)
    |> assign(:ai_error, nil)
    |> assign(:ai_summary, nil)
  end

  defp selected_report_type_param("monthly"), do: "monthly"
  defp selected_report_type_param(_), do: "weekly"

  defp ai_configured?("monthly"), do: MonthlyStorageReportAi.configured?()
  defp ai_configured?(_), do: StorageReportAi.configured?()

  defp current_week_monday do
    today = Timex.now("Europe/Lisbon") |> Timex.to_date()
    Date.add(today, 1 - Date.day_of_week(today))
  end

  defp parse_basin_date_param(nil, fallback), do: fallback

  defp parse_basin_date_param("", fallback), do: fallback

  defp parse_basin_date_param(date_string, fallback) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        if Date.day_of_week(date) == 1 do
          date
        else
          fallback
        end

      _ ->
        fallback
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

  defp date_to_string(%Date{} = date) do
    Calendar.strftime(date, "%Y-%m-%d")
  end

  defp month_to_string(%Date{} = date), do: Calendar.strftime(date, "%Y-%m")

  defp storage_report_path(report_type, selected_basin, selected_date, selected_month) do
    StorageReportPresenter.storage_report_path(
      report_type,
      selected_basin,
      selected_date,
      selected_month
    )
  end

  defp pdf_export_path(report_type, selected_basin, selected_date, selected_month) do
    StorageReportPresenter.pdf_export_path(
      report_type,
      selected_basin,
      selected_date,
      selected_month
    )
  end

  defp build_report("monthly", selected_basin, _selected_date, selected_month) do
    StorageReportPresenter.build_report("monthly", selected_basin, nil, selected_month)
  end

  defp build_report(_report_type, selected_basin, selected_date, _selected_month) do
    StorageReportPresenter.build_report("weekly", selected_basin, selected_date, nil)
  end

  defp period_delta(summary, "monthly"), do: Map.get(summary, :month_delta)
  defp period_delta(summary, _), do: Map.get(summary, :week_delta)

  defp period_delta_from(item, "monthly"), do: Map.get(item, :month_delta)
  defp period_delta_from(item, _), do: Map.get(item, :week_delta)

  defp period_header("monthly"), do: "Mês"
  defp period_header(_), do: "Semana"

  defp period_subtitle("monthly"), do: "vs mês anterior"
  defp period_subtitle(_), do: "vs semana anterior"

  defp reference_subtitle("monthly"), do: "Mesmo mês, anos anteriores"
  defp reference_subtitle(_), do: "Mesma semana do ano, anos anteriores"

  defp storage_metric_label("__all__"), do: "Armazenamento nacional"
  defp storage_metric_label(_basin), do: "Armazenamento da bacia"

  defp format_river(value), do: StorageReportPresenter.format_river(value)

  defp format_pct(nil), do: "n/d"
  defp format_pct(value), do: "#{format_number(value)}%"

  defp format_delta(nil), do: "n/d"
  defp format_delta(value) when value > 0, do: "+#{format_number(value)} %"
  defp format_delta(value), do: "#{format_number(value)} %"

  defp delta_text(nil, label), do: "Sem dados #{label}"
  defp delta_text(value, label), do: "#{format_delta(value)} #{label}"

  defp format_volume(nil), do: "n/d"
  defp format_volume(value), do: "#{format_number(value / @dam3_per_hm3)} hm³"

  defp format_number(value) when is_number(value) do
    :erlang.float_to_binary(value * 1.0, decimals: 1)
  end

  defp format_datetime(nil), do: "n/d"

  defp format_datetime(%NaiveDateTime{} = value) do
    Calendar.strftime(value, "%d/%m/%Y %H:%M")
  end

  defp basin_anchor_id(%{basin_id: basin_id, name: name}) do
    suffix =
      cond do
        is_binary(basin_id) and basin_id != "" -> basin_id
        true -> slugify(name || "basin")
      end

    "basin-#{suffix}"
  end

  defp slugify(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end

  defp format_ai_error(:invalid_report), do: "Não foi possível preparar o relatório para IA."
  defp format_ai_error(:cerebras_api_key_missing), do: "A integração IA não está configurada."
  defp format_ai_error(:cerebras_model_missing), do: "O modelo IA não está configurado."

  defp format_ai_error({:cerebras_http_error, status, _body}),
    do: "O serviço IA respondeu com erro HTTP #{status}."

  defp format_ai_error({:cerebras_transport, reason}),
    do: "Falha de rede ao contactar o serviço IA: #{inspect(reason)}"

  defp format_ai_error({:cerebras_unexpected_body, _}),
    do: "O serviço IA devolveu uma resposta inesperada."

  defp format_ai_error(other), do: "Não foi possível gerar o sumário IA: #{inspect(other)}"

  defp bar_width(nil), do: 0
  defp bar_width(value), do: value |> max(0) |> min(100)

  defp delta_class(nil), do: "text-slate-500 dark:text-slate-400"
  defp delta_class(value) when value > 0, do: "text-emerald-600 dark:text-emerald-400"
  defp delta_class(value) when value < 0, do: "text-rose-600 dark:text-rose-400"
  defp delta_class(_), do: "text-slate-500 dark:text-slate-400"

  defp accent_bg("sky"), do: "bg-sky-500"
  defp accent_bg("teal"), do: "bg-teal-500"
  defp accent_bg("amber"), do: "bg-amber-500"
  defp accent_bg(_), do: "bg-brand-600"

  defp portugal_map_payload(%{basins: basins}) do
    stats_by_basin =
      Map.new(basins, fn basin ->
        {basin_lookup_key(basin.name), basin}
      end)

    basins_geojson = %{
      "type" => "FeatureCollection",
      "features" =>
        Enum.map(hydro_features(), fn feature ->
          zname = get_in(feature, ["properties", "zname"])
          basin = Map.get(stats_by_basin, basin_lookup_key(zname))

          %{
            "type" => "Feature",
            "geometry" => feature["geometry"],
            "properties" => %{
              "name" => zname,
              "fill_color" => if(basin, do: storage_color(basin.current_pct), else: "#cbd5e1"),
              "fill_opacity" => if(basin, do: 0.92, else: 0.45)
            }
          }
        end)
    }

    dams_geojson = %{
      "type" => "FeatureCollection",
      "features" =>
        basins
        |> Enum.flat_map(fn basin ->
          basin.dams
          |> Enum.reduce([], fn dam, acc ->
            case dam.coordinates do
              %{lat: lat, lon: lon} when is_number(lat) and is_number(lon) ->
                [
                  %{
                    "type" => "Feature",
                    "geometry" => %{"type" => "Point", "coordinates" => [lon, lat]},
                    "properties" => %{
                      "name" => dam.name,
                      "color" => storage_color(dam.current_pct)
                    }
                  }
                  | acc
                ]

              _ ->
                acc
            end
          end)
          |> Enum.reverse()
        end)
    }

    %{
      basins_geojson: Jason.encode!(basins_geojson),
      dams_geojson: Jason.encode!(dams_geojson),
      fit_bounds:
        Jason.encode!([
          [@portugal_bounds.min_lon, @portugal_bounds.min_lat],
          [@portugal_bounds.max_lon, @portugal_bounds.max_lat]
        ])
    }
  end

  defp mini_basin_map_payload(basin) do
    with %{} = feature <- hydro_feature_for(basin.name),
         %{} = bounds <- feature["geometry"] |> geometry_bounds() |> expand_bounds(0.12) do
      selected_name = basin_lookup_key(basin.name)

      basin_geojson = %{
        "type" => "FeatureCollection",
        "features" => [
          %{
            "type" => "Feature",
            "geometry" => feature["geometry"],
            "properties" => %{
              "name" => basin.name,
              "fill_color" => storage_color(basin.current_pct)
            }
          }
        ]
      }

      context_geojson = %{
        "type" => "FeatureCollection",
        "features" => context_features_for_bounds(selected_name, bounds)
      }

      dams_geojson = %{
        "type" => "FeatureCollection",
        "features" => mini_map_dam_features(basin)
      }

      %{
        dom_id: mini_map_dom_id(basin),
        basin_geojson: Jason.encode!(basin_geojson),
        context_geojson: Jason.encode!(context_geojson),
        dams_geojson: Jason.encode!(dams_geojson),
        fit_bounds:
          Jason.encode!([
            [bounds.min_lon, bounds.min_lat],
            [bounds.max_lon, bounds.max_lat]
          ])
      }
    else
      _ -> nil
    end
  end

  defp context_features_for_bounds(selected_name, bounds) do
    hydro_features()
    |> Enum.reject(fn feature ->
      feature
      |> get_in(["properties", "zname"])
      |> basin_lookup_key() == selected_name
    end)
    |> Enum.filter(fn feature ->
      feature["geometry"]
      |> geometry_bounds()
      |> bounds_intersect?(bounds)
    end)
    |> Enum.map(fn feature ->
      %{
        "type" => "Feature",
        "geometry" => feature["geometry"],
        "properties" => %{
          "name" => get_in(feature, ["properties", "zname"])
        }
      }
    end)
  end

  defp mini_map_dam_features(basin) do
    basin.dams
    |> Enum.reduce([], fn dam, acc ->
      case dam.coordinates do
        %{lat: lat, lon: lon} when is_number(lat) and is_number(lon) ->
          [
            %{
              "type" => "Feature",
              "geometry" => %{"type" => "Point", "coordinates" => [lon, lat]},
              "properties" => %{
                "name" => dam.name,
                "color" => storage_color(dam.current_pct)
              }
            }
            | acc
          ]

        _ ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  defp mini_map_dom_id(basin) do
    token =
      [Map.get(basin, :basin_id), Map.get(basin, :name)]
      |> Enum.find_value(fn
        value when is_binary(value) ->
          trimmed = String.trim(value)
          if trimmed == "", do: nil, else: trimmed

        _ ->
          nil
      end)
      |> then(fn
        nil -> ""
        value -> normalize_basin_name(value)
      end)
      |> String.replace(~r/[^a-z0-9_-]+/u, "-")
      |> String.trim("-")

    "storage-report-basin-map-" <> if(token == "", do: "unknown", else: token)
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

  defp storage_color(value) when is_number(value) and value <= 20, do: "#ff675c"
  defp storage_color(value) when is_number(value) and value <= 40, do: "#ffc34a"
  defp storage_color(value) when is_number(value) and value <= 50, do: "#ffe99c"
  defp storage_color(value) when is_number(value) and value <= 60, do: "#c2faaa"
  defp storage_color(value) when is_number(value) and value <= 80, do: "#a6d8ff"
  defp storage_color(value) when is_number(value) and value <= 100, do: "#1c9dff"
  defp storage_color(_value), do: "#94a3b8"

  defp storage_bucket_color(:pct_0_20), do: "#ff675c"
  defp storage_bucket_color(:pct_21_40), do: "#ffc34a"
  defp storage_bucket_color(:pct_41_50), do: "#ffe99c"
  defp storage_bucket_color(:pct_51_60), do: "#c2faaa"
  defp storage_bucket_color(:pct_61_80), do: "#a6d8ff"
  defp storage_bucket_color(:pct_81_100), do: "#1c9dff"
  defp storage_bucket_color(_), do: "#94a3b8"

  defp storage_bucket_label(%{key: :unknown, label: label}), do: label
  defp storage_bucket_label(%{label: label}), do: "#{label}%"

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
end
