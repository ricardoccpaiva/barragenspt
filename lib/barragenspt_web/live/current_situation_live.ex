defmodule BarragensptWeb.CurrentSituationLive do
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

  @focus_window_options [1, 3, 6, 9, 12]
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
    dams = current_dams()
    basin_heatmap = basin_heatmap(basins)
    basin_stack_chart = basin_stack_chart_payload(basins)
    selected_focus_basin_id = default_focus_basin_id(dams, basins)
    selected_focus_window_months = 6
    focused_basin = focused_basin_payload(basins, dams, selected_focus_basin_id, selected_focus_window_months)
    selected_flow_basin_id = selected_focus_basin_id
    selected_flow_window_months = 6
    selected_flow_param = default_flow_param()

    focused_flow =
      focused_flow_payload(
        basins,
        dams,
        selected_flow_basin_id,
        selected_flow_window_months,
        selected_flow_param
      )

    socket =
      socket
      |> assign(:page_title, "Situação atual")
      |> assign(:basins, basins)
      |> assign(:current_dams, dams)
      |> assign(:basin_heatmap, basin_heatmap)
      |> assign(:basin_stack_chart, basin_stack_chart)
      |> assign(:selected_focus_basin_id, selected_focus_basin_id)
      |> assign(:selected_focus_window_months, selected_focus_window_months)
      |> assign(:focus_window_options, @focus_window_options)
      |> assign(:flow_param_options, @flow_param_options)
      |> assign(:focused_basin, focused_basin)
      |> assign(:selected_flow_basin_id, selected_flow_basin_id)
      |> assign(:selected_flow_window_months, selected_flow_window_months)
      |> assign(:selected_flow_param, selected_flow_param)
      |> assign(:focused_flow, focused_flow)

    {:ok, socket}
  end

  def handle_event("select_focus_basin", params, socket) do
    basin_id = Map.get(params, "focus_basin_id")
    window_months = resolve_focus_window_months(Map.get(params, "focus_window_months"))
    selected_focus_basin_id = resolve_focus_basin_id(socket.assigns.basins, basin_id)

    focused_basin =
      focused_basin_payload(
        socket.assigns.basins,
        socket.assigns.current_dams,
        selected_focus_basin_id,
        window_months
      )

    {:noreply,
     socket
     |> assign(:selected_focus_basin_id, selected_focus_basin_id)
     |> assign(:selected_focus_window_months, window_months)
     |> assign(:focused_basin, focused_basin)}
  end

  def handle_event("select_flow_chart", params, socket) do
    basin_id = Map.get(params, "flow_basin_id")
    window_months = resolve_focus_window_months(Map.get(params, "flow_window_months"))
    param_slug = resolve_flow_param(Map.get(params, "flow_param"))
    selected_flow_basin_id = resolve_focus_basin_id(socket.assigns.basins, basin_id)

    focused_flow =
      focused_flow_payload(
        socket.assigns.basins,
        socket.assigns.current_dams,
        selected_flow_basin_id,
        window_months,
        param_slug
      )

    {:noreply,
     socket
     |> assign(:selected_flow_basin_id, selected_flow_basin_id)
     |> assign(:selected_flow_window_months, window_months)
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

  defp current_dams do
    Repo.all(
      from(s in SiteCurrentStorage,
        join: d in Dam,
        on: s.site_id == d.site_id,
        where: not is_nil(d.total_capacity),
        select: %{
          site_id: s.site_id,
          basin_id: d.basin_id,
          site_name: d.name,
          current_volume: fragment("round(?)::integer", s.current_storage_value),
          colected_at: s.colected_at
        }
      )
    )
    |> Enum.map(fn dam ->
      current_volume = to_int(dam.current_volume)

      %{
        site_id: dam.site_id,
        basin_id: dam.basin_id,
        site_name: normalize_dam_name(dam.site_name),
        current_volume: current_volume,
        colected_at: dam.colected_at
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

  defp focused_basin_payload(basins, dams, basin_id, window_months) do
    days = trailing_days_from_months(window_months)
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
      window_months: window_months,
      stack_chart: %{
        chart_type: "stacked_area",
        x_max_ticks: focus_chart_tick_limit(window_months),
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

  defp focused_flow_payload(basins, dams, basin_id, window_months, param_slug) do
    days = trailing_days_from_months(window_months)
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
      window_months: window_months,
      stack_chart: %{
        chart_type: "stacked_area",
        x_max_ticks: focus_chart_tick_limit(window_months),
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

  defp trailing_days_from_months(month_count) do
    current_day = Date.utc_today()
    start_day = Timex.shift(current_day, months: -month_count)

    Date.range(start_day, current_day)
    |> Enum.to_list()
    |> Enum.reverse()
  end

  defp focus_chart_tick_limit(months) when months <= 1, do: 8
  defp focus_chart_tick_limit(months) when months <= 3, do: 10
  defp focus_chart_tick_limit(months) when months <= 6, do: 12
  defp focus_chart_tick_limit(_months), do: 14

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

  defp resolve_focus_window_months(value) do
    parsed =
      case Integer.parse(to_string(value || "")) do
        {months, _} -> months
        :error -> nil
      end

    if parsed in @focus_window_options, do: parsed, else: 6
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
