defmodule BarragensptWeb.OverviewLive do
  use BarragensptWeb, :live_view
  import Ecto.Query

  alias Barragenspt.Mappers.Colors
  alias Barragenspt.Hydrometrics.Basins
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

  def handle_event("select_focus_basin", params, socket) do
    basin_id = Map.get(params, "focus_basin_id")
    selected_focus_basin_id = resolve_focus_basin_id(socket.assigns.basins, basin_id)
    {start_date, end_date} = resolve_date_range(params, "focus_start_date", "focus_end_date")

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

  def handle_event("select_flow_chart", params, socket) do
    basin_id = Map.get(params, "flow_basin_id")
    param_slug = resolve_flow_param(Map.get(params, "flow_param"))
    selected_flow_basin_id = resolve_focus_basin_id(socket.assigns.basins, basin_id)
    {start_date, end_date} = resolve_date_range(params, "flow_start_date", "flow_end_date")

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
    days = days_in_range(start_date, end_date)
    basin = Enum.find(basins, &(&1.id == basin_id)) || List.first(basins)
    dams_in_basin = focused_basin_dams(dams, basin && basin.id)
    dam_ids = Enum.map(dams_in_basin, & &1.site_id)
    volume_values = dam_daily_volumes(days, dam_ids)

    series_dams =
      dams_in_basin
      |> Enum.with_index()
      |> Enum.map(fn {dam, idx} ->
        dam
        |> Map.take([:site_id, :site_name])
        |> Map.put(:short_name, short_dam_name(dam.site_name))
        |> Map.put(:series_color, indexed_series_color(idx))
      end)

    %{
      basin: basin,
      dams: series_dams,
      stack_chart: %{
        chart_type: "stacked_area",
        x_max_ticks: focus_chart_tick_limit_from_days(length(days)),
        value_suffix: "hm³",
        labels: Enum.map(Enum.reverse(days), &format_day_label/1),
        datasets:
          Enum.map(series_dams, fn dam ->
            %{
              label: dam.short_name,
              full_label: dam.site_name,
              series_id: dam.site_id,
              data:
                Enum.map(Enum.reverse(days), fn day ->
                  Map.get(volume_values, {day, dam.site_id}, 0)
                end),
              backgroundColor: dam.series_color,
              borderColor: dam.series_color,
              hoverBackgroundColor: dam.series_color,
              stack: "storage"
            }
          end)
      }
    }
  end

  defp focused_flow_payload(basins, dams, basin_id, start_date, end_date, param_slug) do
    days = days_in_range(start_date, end_date)
    basin = Enum.find(basins, &(&1.id == basin_id)) || List.first(basins)
    dams_in_basin = focused_basin_dams(dams, basin && basin.id)
    dam_ids = Enum.map(dams_in_basin, & &1.site_id)
    values = dam_daily_param_values(days, dam_ids, param_slug)
    param_meta = flow_param_meta(param_slug)

    series_dams =
      dams_in_basin
      |> Enum.with_index()
      |> Enum.filter(fn {dam, _idx} ->
        Enum.any?(days, &Map.has_key?(values, {&1, dam.site_id}))
      end)
      |> Enum.map(fn {dam, idx} ->
        dam
        |> Map.take([:site_id, :site_name])
        |> Map.put(:short_name, short_dam_name(dam.site_name))
        |> Map.put(:series_color, indexed_series_color(idx))
      end)

    %{
      basin: basin,
      param: param_meta,
      dams: series_dams,
      stack_chart: %{
        chart_type: "stacked_area",
        x_max_ticks: focus_chart_tick_limit_from_days(length(days)),
        value_suffix: param_meta.unit,
        labels: Enum.map(Enum.reverse(days), &format_day_label/1),
        datasets:
          Enum.map(series_dams, fn dam ->
            %{
              label: dam.short_name,
              full_label: dam.site_name,
              series_id: dam.site_id,
              data:
                Enum.map(Enum.reverse(days), fn day ->
                  Map.get(values, {day, dam.site_id})
                end),
              backgroundColor: dam.series_color,
              borderColor: dam.series_color,
              hoverBackgroundColor: dam.series_color,
              stack: "storage"
            }
          end)
      }
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

  defp dam_daily_volumes(days, dam_ids) do
    if dam_ids == [] do
      %{}
    else
      start_day = List.last(days) |> Timex.to_naive_datetime()
      next_day_start = List.first(days) |> Timex.shift(days: 1) |> Timex.to_naive_datetime()

      daily_points =
        from(dp in DataPoint,
          join: d in Dam,
          on: d.site_id == dp.site_id,
          where:
            dp.param_name == "volume_last_hour" and
              dp.colected_at >= ^start_day and
              dp.colected_at < ^next_day_start and
              d.site_id in ^dam_ids,
          select: %{
            site_id: d.site_id,
            value: dp.value,
            day: fragment("date_trunc('day', ?)::date", dp.colected_at),
            rn:
              over(
                row_number(),
                :site_day_window
              )
          },
          windows: [
            site_day_window: [
              partition_by: [dp.site_id, fragment("date_trunc('day', ?)", dp.colected_at)],
              order_by: [desc: dp.colected_at]
            ]
          ]
        )

      from(p in subquery(daily_points),
        where: p.rn == 1,
        select: %{
          day: p.day,
          site_id: p.site_id,
          volume: fragment("round(?)::integer", p.value)
        }
      )
      |> Repo.all()
      |> Map.new(fn row ->
        {{row.day, row.site_id}, to_int(row.volume)}
      end)
    end
  end

  defp dam_daily_param_values(days, dam_ids, param_slug) do
    if dam_ids == [] do
      %{}
    else
      start_day = List.last(days) |> Timex.to_naive_datetime()
      next_day_start = List.first(days) |> Timex.shift(days: 1) |> Timex.to_naive_datetime()

      daily_points =
        from(dp in DataPoint,
          join: d in Dam,
          on: d.site_id == dp.site_id,
          where:
            dp.param_name == ^param_slug and
              dp.colected_at >= ^start_day and
              dp.colected_at < ^next_day_start and
              d.site_id in ^dam_ids,
          select: %{
            site_id: d.site_id,
            value: dp.value,
            day: fragment("date_trunc('day', ?)::date", dp.colected_at),
            rn:
              over(
                row_number(),
                :site_day_window
              )
          },
          windows: [
            site_day_window: [
              partition_by: [dp.site_id, fragment("date_trunc('day', ?)", dp.colected_at)],
              order_by: [desc: dp.colected_at]
            ]
          ]
        )

      from(p in subquery(daily_points),
        where: p.rn == 1,
        select: %{
          day: p.day,
          site_id: p.site_id,
          value: fragment("round(?, 2)", p.value)
        }
      )
      |> Repo.all()
      |> Map.new(fn row ->
        {{row.day, row.site_id}, to_float(row.value)}
      end)
    end
  end

  defp trailing_months(count) do
    current_month = Date.utc_today() |> Date.beginning_of_month()

    0..(count - 1)
    |> Enum.map(fn index -> Timex.shift(current_month, months: -index) end)
  end

  defp days_in_range(%Date{} = start_date, %Date{} = end_date) do
    {start_date, end_date} = normalize_date_range(start_date, end_date)

    Date.range(start_date, end_date)
    |> Enum.to_list()
    |> Enum.reverse()
  end

  defp focus_chart_tick_limit_from_days(days) when days <= 45, do: 8
  defp focus_chart_tick_limit_from_days(days) when days <= 120, do: 10
  defp focus_chart_tick_limit_from_days(days) when days <= 220, do: 12
  defp focus_chart_tick_limit_from_days(_days), do: 14

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
