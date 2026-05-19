defmodule BarragensptWeb.OverviewLive do
  use BarragensptWeb, :live_view
  import Ecto.Query

  alias Barragenspt.Activity
  alias Barragenspt.Mappers.Colors
  alias Barragenspt.Hydrometrics.{Basins, Dams}
  alias Barragenspt.Models.Hydrometrics.{Dam, DataPoint, SiteCurrentStorage}
  alias Barragenspt.Repo

  @basin_series_palette [
    "#7fb3ff",
    "#7fd3c8",
    "#b59cff",
    "#ffbe8a",
    "#f59ab0",
    "#8fd3e8",
    "#b8dc86",
    "#e6be7a",
    "#9ea8ff",
    "#86d6d0",
    "#f2aa7e",
    "#c7a0eb",
    "#8cbfe0",
    "#a9cf8f"
  ]

  @flow_param_options [
    %{
      slug: "tributary_daily_flow",
      label: "Caudal afluente médio diário",
      unit: "m3/s"
    },
    %{
      slug: "effluent_daily_flow",
      label: "Caudal efluente médio diário",
      unit: "m3/s"
    },
    %{
      slug: "ouput_flow_rate_daily",
      label: "Caudal descarregado médio diário",
      unit: "m3/s"
    },
    %{
      slug: "turbocharged_daily_flow",
      label: "Caudal turbinado médio diário",
      unit: "m3/s"
    }
  ]

  def mount(_params, _session, socket) do
    if connected?(socket) do
      track_overview_report_view(socket)
    end

    basins = current_basins()
    dams = chart_dams()
    basin_heatmap = basin_heatmap(basins)
    basin_stack_chart = basin_stack_chart_payload(basins)
    selected_focus_basin_id = default_focus_basin_id(dams, basins)
    {selected_focus_start_date, selected_focus_end_date} =
      default_focus_date_range()

    focused_basin =
      focused_basin_payload(
        basins,
        dams,
        selected_focus_basin_id,
        selected_focus_start_date,
        selected_focus_end_date
      )

    selected_flow_basin_id = selected_focus_basin_id
    {selected_flow_start_date, selected_flow_end_date} =
      default_focus_date_range()
    selected_flow_param = default_flow_param()

    focused_flow =
      focused_flow_payload(
        basins,
        dams,
        selected_flow_basin_id,
        selected_flow_start_date,
        selected_flow_end_date,
        selected_flow_param
      )

    socket =
      socket
      |> assign(:page_title, "Overview")
      |> assign(:basins, basins)
      |> assign(:current_dams, dams)
      |> assign(:basin_heatmap, basin_heatmap)
      |> assign(:basin_stack_chart, basin_stack_chart)
      |> assign(:selected_focus_basin_id, selected_focus_basin_id)
      |> assign(:selected_focus_start_date, Date.to_iso8601(selected_focus_start_date))
      |> assign(:selected_focus_end_date, Date.to_iso8601(selected_focus_end_date))
      |> assign(:flow_param_options, @flow_param_options)
      |> assign(:focused_basin, focused_basin)
      |> assign(:selected_flow_basin_id, selected_flow_basin_id)
      |> assign(:selected_flow_start_date, Date.to_iso8601(selected_flow_start_date))
      |> assign(:selected_flow_end_date, Date.to_iso8601(selected_flow_end_date))
      |> assign(:selected_flow_param, selected_flow_param)
      |> assign(:focused_flow, focused_flow)

    {:ok, socket}
  end

  defp track_overview_report_view(socket) do
    user_id = get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:id)])

    metadata = %{
      "report_type" => "overview",
      "source" => "dashboard_overview"
    }

    _ = Activity.record_event(user_id, Activity.report_generated_event(), metadata)
  end

  def handle_event("select_focus_basin", params, socket) do
    basin_id = Map.get(params, "focus_basin_id")
    selected_focus_basin_id = resolve_focus_basin_id(socket.assigns.basins, basin_id)
    {start_date, end_date} = resolve_date_range(params, "focus_start_date", "focus_end_date")

    if same_focus_filters?(
         socket.assigns,
         selected_focus_basin_id,
         start_date,
         end_date
       ) do
      {:noreply, socket}
    else
      focused_basin =
        focused_basin_payload(
          socket.assigns.basins,
          socket.assigns.current_dams,
          selected_focus_basin_id,
          start_date,
          end_date
        )

      {:noreply,
       socket
       |> assign(:selected_focus_basin_id, selected_focus_basin_id)
       |> assign(:selected_focus_start_date, Date.to_iso8601(start_date))
       |> assign(:selected_focus_end_date, Date.to_iso8601(end_date))
       |> assign(:focused_basin, focused_basin)}
    end
  end

  def handle_event("select_flow_chart", params, socket) do
    basin_id = Map.get(params, "flow_basin_id")
    param_slug = resolve_flow_param(Map.get(params, "flow_param"))
    selected_flow_basin_id = resolve_focus_basin_id(socket.assigns.basins, basin_id)
    {start_date, end_date} = resolve_date_range(params, "flow_start_date", "flow_end_date")

    if same_flow_filters?(
         socket.assigns,
         selected_flow_basin_id,
         param_slug,
         start_date,
         end_date
       ) do
      {:noreply, socket}
    else
      focused_flow =
        focused_flow_payload(
          socket.assigns.basins,
          socket.assigns.current_dams,
          selected_flow_basin_id,
          start_date,
          end_date,
          param_slug
        )

      {:noreply,
       socket
       |> assign(:selected_flow_basin_id, selected_flow_basin_id)
       |> assign(:selected_flow_start_date, Date.to_iso8601(start_date))
       |> assign(:selected_flow_end_date, Date.to_iso8601(end_date))
       |> assign(:selected_flow_param, param_slug)
       |> assign(:focused_flow, focused_flow)}
    end
  end

  defp current_basins do
    Basins.summary_stats([])
    |> Enum.map(fn basin ->
      current_pct = to_float(basin.observed_value)

      %{
        id: basin.id,
        name: basin.name,
        current_pct: current_pct,
        current_pct_label: format_pct(current_pct),
        current_volume: to_int(basin.current_storage_volume),
        current_volume_label: format_volume(to_int(basin.current_storage_volume))
      }
    end)
    |> Enum.sort_by(&{-&1.current_pct, &1.name})
  end

  defp chart_dams do
    Repo.all(
      from(s in SiteCurrentStorage,
        join: d in Dam,
        on: s.site_id == d.site_id,
        where: not is_nil(d.total_capacity),
        select: %{
          site_id: s.site_id,
          basin_id: d.basin_id,
          site_name: d.name,
          current_volume: fragment("round(?)::integer", s.current_storage_value)
        }
      )
    )
    |> Enum.map(fn dam ->
      current_volume = to_int(dam.current_volume)

      %{
        site_id: dam.site_id,
        basin_id: dam.basin_id,
        site_name: normalize_dam_name(dam.site_name),
        current_volume: current_volume
      }
    end)
  end

  defp basin_heatmap(basins) do
    months = trailing_months(12)
    basin_ids = Enum.map(basins, & &1.id)
    values = basin_monthly_values(months, basin_ids)

    %{
      basins:
        Enum.map(basins, fn basin ->
          basin
          |> Map.take([:id, :name, :current_pct, :current_pct_label])
          |> Map.put(:short_name, short_basin_name(basin.name))
          |> Map.put(:series_color, basin_series_color(basin, basins))
        end),
      rows:
        Enum.map(months, fn month ->
          %{
            month: month,
            label: format_month_label(month),
            cells:
              Enum.map(basins, fn basin ->
                pct = Map.get(values, {month, basin.id})

                %{
                  basin_id: basin.id,
                  basin_name: basin.name,
                  pct: pct,
                  pct_label: if(is_number(pct), do: format_pct(pct), else: "—"),
                  color: if(is_number(pct), do: Colors.lookup_capacity(pct), else: "#e2e8f0")
                }
              end)
          }
        end)
    }
  end

  defp basin_stack_chart_payload(basins) do
    months = trailing_months(12)
    basin_ids = Enum.map(basins, & &1.id)
    volumes = basin_monthly_volumes(months, basin_ids)

    %{
      chart_type: "stacked_bar",
      value_suffix: "hm³",
      labels: Enum.map(Enum.reverse(months), &format_month_label/1),
      datasets:
        Enum.map(basins, fn basin ->
          color = basin_series_color(basin, basins)

          %{
            label: short_basin_name(basin.name),
            full_label: basin.name,
            basin_id: basin.id,
            data:
              Enum.map(Enum.reverse(months), fn month ->
                Map.get(volumes, {month, basin.id}, 0)
              end),
            backgroundColor: color,
            borderColor: color,
            hoverBackgroundColor: color,
            stack: "storage"
          }
        end)
    }
  end

  defp focused_basin_payload(basins, dams, basin_id, start_date, end_date) do
    basin = Enum.find(basins, &(&1.id == basin_id)) || List.first(basins)
    dams_in_basin = focused_basin_dams(dams, basin && basin.id)

    series_dams =
      dams_in_basin
      |> Enum.with_index()
      |> Enum.map(fn {dam, idx} ->
        dam
        |> Map.take([:site_id, :site_name])
        |> Map.put(:short_name, short_dam_name(dam.site_name))
        |> Map.put(:series_color, indexed_series_color(idx))
      end)

    chart_payload =
      bucketed_focus_chart_payload(
        series_dams,
        "volume_last_hour",
        start_date,
        end_date,
        "hm³"
      )

    %{
      basin: basin,
      granularity: chart_payload.granularity,
      granularity_label: chart_payload.granularity_label,
      dams: chart_payload.series_dams,
      stack_chart: chart_payload.stack_chart
    }
  end

  defp focused_flow_payload(basins, dams, basin_id, start_date, end_date, param_slug) do
    basin = Enum.find(basins, &(&1.id == basin_id)) || List.first(basins)
    dams_in_basin = focused_basin_dams(dams, basin && basin.id)
    param_meta = flow_param_meta(param_slug)

    series_dams =
      dams_in_basin
      |> Enum.with_index()
      |> Enum.map(fn {dam, idx} ->
        dam
        |> Map.take([:site_id, :site_name])
        |> Map.put(:short_name, short_dam_name(dam.site_name))
        |> Map.put(:series_color, indexed_series_color(idx))
      end)

    chart_payload =
      bucketed_focus_chart_payload(
        series_dams,
        param_slug,
        start_date,
        end_date,
        param_meta.unit
      )

    %{
      basin: basin,
      param: param_meta,
      granularity: chart_payload.granularity,
      granularity_label: chart_payload.granularity_label,
      dams: chart_payload.series_dams,
      stack_chart: chart_payload.stack_chart
    }
  end

  defp basin_monthly_values(months, basin_ids) do
    start_month = List.last(months) |> Date.beginning_of_month() |> Timex.to_naive_datetime()
    next_month_start = List.first(months) |> Timex.shift(months: 1) |> Timex.to_naive_datetime()

    monthly_points =
      from(dp in DataPoint,
        join: d in Dam,
        on: d.site_id == dp.site_id,
        where:
          dp.param_name == "volume_last_hour" and
            dp.colected_at >= ^start_month and
            dp.colected_at < ^next_month_start and
            d.basin_id in ^basin_ids and
            not is_nil(d.total_capacity),
        select: %{
          basin_id: d.basin_id,
          site_id: dp.site_id,
          value: dp.value,
          total_capacity: d.total_capacity,
          month: fragment("date_trunc('month', ?)::date", dp.colected_at),
          rn:
            over(
              row_number(),
              :site_month_window
            )
        },
        windows: [
          site_month_window: [
            partition_by: [dp.site_id, fragment("date_trunc('month', ?)", dp.colected_at)],
            order_by: [desc: dp.colected_at]
          ]
        ]
      )

    from(p in subquery(monthly_points),
      where: p.rn == 1,
      group_by: [p.month, p.basin_id],
      select: %{
        month: p.month,
        basin_id: p.basin_id,
        pct: fragment("round(sum(?) / sum(?) * 100.0, 1)", p.value, p.total_capacity)
      }
    )
    |> Repo.all()
    |> Map.new(fn row ->
      {{row.month, row.basin_id}, to_float(row.pct)}
    end)
  end

  defp basin_monthly_volumes(months, basin_ids) do
    start_month = List.last(months) |> Date.beginning_of_month() |> Timex.to_naive_datetime()
    next_month_start = List.first(months) |> Timex.shift(months: 1) |> Timex.to_naive_datetime()

    monthly_points =
      from(dp in DataPoint,
        join: d in Dam,
        on: d.site_id == dp.site_id,
        where:
          dp.param_name == "volume_last_hour" and
            dp.colected_at >= ^start_month and
            dp.colected_at < ^next_month_start and
            d.basin_id in ^basin_ids and
            not is_nil(d.total_capacity),
        select: %{
          basin_id: d.basin_id,
          site_id: dp.site_id,
          value: dp.value,
          month: fragment("date_trunc('month', ?)::date", dp.colected_at),
          rn:
            over(
              row_number(),
              :site_month_window
            )
        },
        windows: [
          site_month_window: [
            partition_by: [dp.site_id, fragment("date_trunc('month', ?)", dp.colected_at)],
            order_by: [desc: dp.colected_at]
          ]
        ]
      )

    from(p in subquery(monthly_points),
      where: p.rn == 1,
      group_by: [p.month, p.basin_id],
      select: %{
        month: p.month,
        basin_id: p.basin_id,
        volume: fragment("round(sum(?))::integer", p.value)
      }
    )
    |> Repo.all()
    |> Map.new(fn row ->
      {{row.month, row.basin_id}, to_int(row.volume)}
    end)
  end

  defp trailing_months(count) do
    current_month = Date.utc_today() |> Date.beginning_of_month()

    0..(count - 1)
    |> Enum.map(fn index -> Timex.shift(current_month, months: -index) end)
  end

  defp focus_chart_granularity(%Date{} = start_date, %Date{} = end_date) do
    two_year_threshold = Timex.shift(end_date, years: -2)
    nine_month_threshold = Timex.shift(end_date, months: -9)

    cond do
      Date.compare(start_date, two_year_threshold) in [:lt, :eq] -> :month
      Date.compare(start_date, nine_month_threshold) in [:lt, :eq] -> :week
      true -> :day
    end
  end

  defp bucketed_focus_chart_payload(series_dams, param_slug, start_date, end_date, value_suffix) do
    preferred_grain = focus_chart_granularity(start_date, end_date)
    site_ids = Enum.map(series_dams, & &1.site_id)

    case Dams.bucketed_site_series_for_ui(site_ids, param_slug, start_date, end_date, preferred_grain) do
      {:ok, rows, meta} ->
        granularity = Map.get(meta, :grain, preferred_grain)
        buckets = rows |> Enum.map(& &1["bucket"]) |> Enum.reject(&is_nil/1) |> Enum.uniq() |> Enum.sort()
        labels = Enum.map(buckets, &format_focus_bucket_label(&1, granularity))
        label_by_bucket = Map.new(Enum.zip(buckets, labels))

        rows_by_series_and_bucket =
          Map.new(rows, fn row ->
            {{row["site_id"], row["bucket"]}, row["avg_value"]}
          end)

        datasets =
          series_dams
          |> Enum.map(fn dam ->
            %{
              label: dam.short_name,
              full_label: dam.site_name,
              series_id: dam.site_id,
              data: Enum.map(buckets, &Map.get(rows_by_series_and_bucket, {dam.site_id, &1})),
              backgroundColor: dam.series_color,
              borderColor: dam.series_color,
              hoverBackgroundColor: dam.series_color,
              stack: "storage"
            }
          end)
          |> Enum.filter(fn dataset -> Enum.any?(dataset.data, &(!is_nil(&1))) end)

        visible_series_ids = MapSet.new(Enum.map(datasets, & &1.series_id))

        %{
          granularity: granularity,
          granularity_label: focus_chart_granularity_label(granularity),
          series_dams: Enum.filter(series_dams, &MapSet.member?(visible_series_ids, &1.site_id)),
          stack_chart: %{
            chart_type: "stacked_area",
            x_max_ticks: focus_chart_tick_limit(length(labels), granularity),
            value_suffix: value_suffix,
            labels: Enum.map(buckets, &label_by_bucket[&1]),
            datasets: datasets
          }
        }

      _ ->
        %{
          granularity: preferred_grain,
          granularity_label: focus_chart_granularity_label(preferred_grain),
          series_dams: [],
          stack_chart: %{
            chart_type: "stacked_area",
            x_max_ticks: focus_chart_tick_limit(0, preferred_grain),
            value_suffix: value_suffix,
            labels: [],
            datasets: []
          }
        }
    end
  end

  defp focus_chart_tick_limit(count, :day) when count <= 45, do: 8
  defp focus_chart_tick_limit(count, :day) when count <= 120, do: 10
  defp focus_chart_tick_limit(count, :day) when count <= 220, do: 12
  defp focus_chart_tick_limit(_count, :day), do: 14
  defp focus_chart_tick_limit(count, :week) when count <= 18, do: 8
  defp focus_chart_tick_limit(count, :week) when count <= 30, do: 10
  defp focus_chart_tick_limit(count, :week) when count <= 45, do: 12
  defp focus_chart_tick_limit(_count, :week), do: 14
  defp focus_chart_tick_limit(count, :month) when count <= 18, do: 8
  defp focus_chart_tick_limit(count, :month) when count <= 30, do: 10
  defp focus_chart_tick_limit(_count, :month), do: 12

  defp format_month_label(%Date{} = date) do
    month =
      ~w(Jan Fev Mar Abr Mai Jun Jul Ago Set Out Nov Dez)
      |> Enum.at(date.month - 1)

    "#{month} #{date.year}"
  end

  defp format_day_label(%Date{} = date) do
    month =
      ~w(Jan Fev Mar Abr Mai Jun Jul Ago Set Out Nov Dez)
      |> Enum.at(date.month - 1)

    "#{date.day} #{month}"
  end

  defp format_focus_bucket_label(bucket, granularity) when is_binary(bucket) do
    with {:ok, ndt} <- NaiveDateTime.from_iso8601(bucket) do
      format_focus_bucket_label(NaiveDateTime.to_date(ndt), granularity)
    else
      _ -> bucket
    end
  end

  defp format_focus_bucket_label(%Date{} = date, :day), do: format_day_label(date)
  defp format_focus_bucket_label(%Date{} = date, :week), do: "Sem #{format_day_label(date)}"
  defp format_focus_bucket_label(%Date{} = date, :month), do: format_month_label(date)

  defp focus_chart_granularity_label(:day), do: "Diário"
  defp focus_chart_granularity_label(:week), do: "Semanal"
  defp focus_chart_granularity_label(:month), do: "Mensal"

  defp short_basin_name(nil), do: "—"

  defp short_basin_name(name) when is_binary(name) do
    cleaned =
      name
      |> String.replace("/", " ")
      |> String.replace(~r/\b[Rr]ibeiras?\b/, "")
      |> String.replace(~r/\b[Dd](o|a|os|as)\b/, "")
      |> String.trim()
      |> String.split(~r/\s+/, trim: true)

    case cleaned do
      [] ->
        name

      [single] ->
        single

      [first, second | _] ->
        if String.length(first) <= 3 do
          "#{first} #{second}"
        else
          first
        end
    end
  end

  defp short_dam_name(nil), do: "—"

  defp short_dam_name(name) when is_binary(name) do
    name
    |> normalize_dam_name()
    |> String.trim()
    |> String.slice(0, 12)
  end

  defp basin_series_color(basin, basins) do
    index = Enum.find_index(basins, &(&1.id == basin.id)) || 0
    indexed_series_color(index)
  end

  defp indexed_series_color(index) when is_integer(index) do
    Enum.at(@basin_series_palette, rem(index, length(@basin_series_palette)))
  end

  defp default_focus_basin_id(dams, basins) do
    basin_id =
      dams
      |> Enum.frequencies_by(& &1.basin_id)
      |> Enum.max_by(fn {_basin_id, count} -> count end, fn -> nil end)
      |> case do
        {id, _count} -> id
        nil -> basins |> List.first() |> then(&(&1 && &1.id))
      end

    resolve_focus_basin_id(basins, basin_id)
  end

  defp resolve_focus_basin_id(basins, basin_id) do
    if Enum.any?(basins, &(&1.id == basin_id)) do
      basin_id
    else
      basins |> List.first() |> then(&(&1 && &1.id))
    end
  end

  defp default_focus_date_range do
    end_date = Date.utc_today()
    start_date = Timex.shift(end_date, years: -1)
    {start_date, end_date}
  end

  defp same_focus_filters?(assigns, basin_id, %Date{} = start_date, %Date{} = end_date) do
    assigns.selected_focus_basin_id == basin_id and
      assigns.selected_focus_start_date == Date.to_iso8601(start_date) and
      assigns.selected_focus_end_date == Date.to_iso8601(end_date)
  end

  defp same_flow_filters?(assigns, basin_id, param_slug, %Date{} = start_date, %Date{} = end_date) do
    assigns.selected_flow_basin_id == basin_id and
      assigns.selected_flow_param == param_slug and
      assigns.selected_flow_start_date == Date.to_iso8601(start_date) and
      assigns.selected_flow_end_date == Date.to_iso8601(end_date)
  end

  defp resolve_date_range(params, start_key, end_key) do
    {default_start_date, default_end_date} = default_focus_date_range()

    start_date =
      params
      |> Map.get(start_key)
      |> parse_date_param(default_start_date)

    end_date =
      params
      |> Map.get(end_key)
      |> parse_date_param(default_end_date)

    normalize_date_range(start_date, end_date)
  end

  defp parse_date_param(value, fallback) do
    case Date.from_iso8601(to_string(value || "")) do
      {:ok, date} -> date
      _ -> fallback
    end
  end

  defp normalize_date_range(%Date{} = start_date, %Date{} = end_date) do
    if Date.compare(start_date, end_date) == :gt do
      {end_date, start_date}
    else
      {start_date, end_date}
    end
  end

  defp default_flow_param, do: @flow_param_options |> List.first() |> Map.fetch!(:slug)

  defp resolve_flow_param(value) do
    slug = to_string(value || "")
    valid = Enum.map(@flow_param_options, & &1.slug)
    if slug in valid, do: slug, else: default_flow_param()
  end

  defp flow_param_meta(slug) do
    Enum.find(@flow_param_options, &(&1.slug == slug)) || List.first(@flow_param_options)
  end

  defp focused_basin_dams(_dams, nil), do: []

  defp focused_basin_dams(dams, basin_id) do
    dams
    |> Enum.filter(&(&1.basin_id == basin_id))
    |> Enum.sort_by(&{-&1.current_volume, &1.site_name})
  end

  defp normalize_dam_name(nil), do: nil

  defp normalize_dam_name(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.replace(~r/^albufeira\s+(de|da|do|das|dos)\s+/i, "")
  end

  defp to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp to_float(n) when is_integer(n), do: n * 1.0
  defp to_float(n) when is_float(n), do: n
  defp to_float(_), do: 0.0

  defp to_int(%Decimal{} = d), do: d |> Decimal.round(0) |> Decimal.to_integer()
  defp to_int(n) when is_integer(n), do: n
  defp to_int(n) when is_float(n), do: round(n)
  defp to_int(_), do: 0

  defp format_pct(value) when is_number(value) do
    "#{:erlang.float_to_binary(value * 1.0, decimals: 1)}%"
  end

  defp format_pct(_), do: "—"

  defp format_volume(value) when is_integer(value) do
    formatted =
      value
      |> Integer.to_string()
      |> String.reverse()
      |> String.replace(~r/.{3}(?=.)/, "\\0 ")
      |> String.reverse()

    "#{formatted} hm³"
  end

  defp format_volume(_), do: "—"

end
