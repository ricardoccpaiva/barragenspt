defmodule Barragenspt.Notifications.AlertMetrics do
  @moduledoc """
  Resolves current metric values for `UserAlert` configurations.
  """
  alias Barragenspt.Hydrometrics.Dams
  alias Barragenspt.Notifications.UserAlert

  @doc "Returns the current numeric value for the alert's metric, or nil if unavailable."
  def current_value(%UserAlert{} = a) do
    current_value(%{subject_type: a.subject_type, subject_id: a.subject_id, metric: a.metric})
  end

  def current_value(%{subject_type: "dam", subject_id: sid, metric: m}), do: dam_value(sid, m)
  def current_value(%{subject_type: _st}), do: nil

  def current_value(_), do: nil

  @doc "True if the condition (operator vs threshold) is satisfied."
  def condition_met?(value, _op, _threshold) when value == nil, do: false
  def condition_met?(value, "lt", t), do: value < t
  def condition_met?(value, "gt", t), do: value > t
  def condition_met?(_, _, _), do: false

  defp dam_value(nil, _), do: nil

  defp dam_value(site_id, "storage_pct") do
    case Dams.current_storage(site_id) do
      %{current_storage: s} -> decimal_to_float(s)
      _ -> nil
    end
  end

  defp dam_value(site_id, "month_change_pct") do
    site_id |> Dams.daily_stats(2) |> period_change(31, 1)
  end

  defp dam_value(site_id, "year_change_pct") do
    site_id |> Dams.monthly_stats(2) |> period_change(365, 45)
  end

  defp dam_value(site_id, "realtime_level") do
    Dams.realtime_latest_value(site_id, "cota")
  end

  defp dam_value(site_id, "realtime_inflow") do
    Dams.realtime_latest_value(site_id, "caudal_afluente")
  end

  defp dam_value(site_id, "realtime_outflow") do
    Dams.realtime_latest_value(site_id, "caudal_efluente")
  end

  defp dam_value(site_id, "realtime_storage") do
    Dams.realtime_latest_value(site_id, "volume_armazenado")
  end

  defp dam_value(site_id, "daily_discharged_flow") do
    Dams.latest_data_point_value(site_id, "ouput_flow_rate_daily")
  end

  defp dam_value(site_id, "daily_tributary_flow") do
    Dams.latest_data_point_value(site_id, "tributary_daily_flow")
  end

  defp dam_value(site_id, "daily_effluent_flow") do
    Dams.latest_data_point_value(site_id, "effluent_daily_flow")
  end

  defp dam_value(site_id, "daily_turbocharged_flow") do
    Dams.latest_data_point_value(site_id, "turbocharged_daily_flow")
  end

  defp dam_value(_, _), do: nil

  defp decimal_to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp decimal_to_float(n) when is_number(n), do: n * 1.0
  defp decimal_to_float(_), do: nil

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

  defp period_value(stats, target_days, max_distance_days) do
    case period_point(stats, target_days, max_distance_days) do
      %{observed_value: point_value} -> point_value
      _ -> nil
    end
  end

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
end
