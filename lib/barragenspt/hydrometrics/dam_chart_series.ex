defmodule Barragenspt.Hydrometrics.DamChartSeries do
  @moduledoc """
  Builds chart series for dam storage and discharge charts.
  Used by HomepageV2Live (handle_params) and DamCardComponent (dam_change_window).
  """

  alias Barragenspt.Hydrometrics.Dams

  @period_config %{
    "d7" => {:daily, 1, 7, "%d/%m"},
    "d14" => {:daily, 1, 14, "%d/%m"},
    "d30" => {:daily, 1, 30, "%d/%m"},
    "d60" => {:daily, 2, 60, "%d/%m"},
    "d180" => {:daily, 6, 180, "%d/%m"},
    "y2" => {:monthly, 2, 24, "%m/%Y"},
    "y5" => {:monthly, 5, 60, "%m/%Y"},
    "y10" => {:monthly, 10, 120, "%m/%Y"},
    "ymax" => {:monthly, 50, nil, "%m/%Y"}
  }

  @doc """
  Returns storage series for the given dam and period, in the format expected by
  the dam_chart_series push_event (e.g. %{"d60" => %{"labels" => ..., "observed" => ..., "average" => ...}}).
  """
  def storage_series(dam_id, period) when is_map_key(@period_config, period) do
    {points, date_format} = fetch_points_for_period(dam_id, period)
    series = build_series_from_points(points, date_format)
    %{period => series}
  end

  def storage_series(_dam_id, _period), do: %{}

  @doc """
  Returns discharge series for the given dam and period, in the format expected by
  the dam_discharge_series push_event.
  """
  def discharge_series(dam_id, period) when is_map_key(@period_config, period) do
    raw = fetch_discharge_flows_for_period(dam_id, period)
    data = slice_discharge_series(raw, period)
    %{period => data}
  end

  def discharge_series(_dam_id, _period), do: %{}

  @doc """
  Returns true if the given period key is valid.
  """
  def valid_period?(period), do: is_map_key(@period_config, period)

  defp fetch_points_for_period(dam_id, period) when is_map_key(@period_config, period) do
    {stats_type, fetch_arg, take_n, date_format} = @period_config[period]

    points =
      case stats_type do
        :daily -> dam_id |> Dams.daily_stats(fetch_arg) |> Enum.map(&normalize_stat/1)
        :monthly -> dam_id |> Dams.monthly_stats(fetch_arg) |> Enum.map(&normalize_stat/1)
      end

    points = if take_n, do: Enum.take(points, -take_n), else: points
    {points, date_format}
  end

  defp normalize_stat(%{date: date, observed_value: obs, historical_average: avg}) do
    %{
      date: date,
      observed_value: to_float(obs),
      historical_average: to_float(avg)
    }
  end

  defp build_series_from_points(points, date_format) do
    labels = Enum.map(points, fn %{date: date} -> Calendar.strftime(date, date_format) end)
    observed = Enum.map(points, & &1.observed_value)
    average = Enum.map(points, & &1.historical_average)
    %{"labels" => labels, "observed" => observed, "average" => average}
  end

  defp fetch_discharge_flows_for_period(dam_id, period)
       when is_map_key(@period_config, period) do
    {stats_type, fetch_arg, _take_n, _date_format} = @period_config[period]

    case stats_type do
      :daily -> Dams.discharge_flows_daily(dam_id, fetch_arg)
      :monthly -> Dams.discharge_flows_monthly(dam_id, fetch_arg)
    end
  end

  defp slice_discharge_series(raw, period) do
    {_stats_type, _fetch_arg, take_n, _date_format} = @period_config[period]
    labels = raw["labels"] || []

    labels =
      if take_n && length(labels) > take_n do
        labels |> Enum.take(-take_n)
      else
        labels
      end

    param_keys = [
      "ouput_flow_rate_daily",
      "tributary_daily_flow",
      "effluent_daily_flow",
      "turbocharged_daily_flow"
    ]

    series =
      for key <- param_keys, reduce: %{} do
        acc -> Map.put(acc, key, raw[key] |> take_tail_or_all(take_n))
      end

    Map.put(series, "labels", labels)
  end

  defp take_tail_or_all(list, nil), do: list || []
  defp take_tail_or_all(list, n) when is_list(list) and is_integer(n), do: Enum.take(list, -n)
  defp take_tail_or_all(list, _), do: list || []

  defp to_float(nil), do: 0.0
  defp to_float(%Decimal{} = d), do: d |> Decimal.to_float()
  defp to_float(n) when is_number(n), do: n * 1.0
end
