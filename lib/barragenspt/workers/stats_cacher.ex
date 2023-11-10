defmodule Barragenspt.Workers.StatsCacher do
  use Oban.Worker, queue: :stats_cacher
  alias Barragenspt.Hydrometrics.Dams
  alias Barragenspt.Hydrometrics.Basins
  require Logger

  @impl Oban.Worker
  def perform(_args) do
    Barragenspt.Cache.flush()

    dams = Dams.all()

    usage_types_combinations =
      Dams.all_usage_types()
      |> Enum.map(fn du -> du.usage_name end)
      |> Enum.uniq()
      |> get_usage_types_combinations()

    basin_ids =
      dams
      |> Enum.uniq_by(fn %{basin_id: basin_id} -> basin_id end)
      |> Enum.map(fn %{basin_id: basin_id} -> basin_id end)

    hourly_periods = [1, 2]
    daily_periods = [1, 6]
    monthly_periods = [2, 5, 10, 50]

    cache_dams_stats(
      dams,
      hourly_periods,
      daily_periods,
      monthly_periods,
      usage_types_combinations
    )

    cache_basin_stats(basin_ids, daily_periods, monthly_periods, usage_types_combinations)

    cache_discharge_stats(dams, hourly_periods, daily_periods, monthly_periods)
    :ok
  end

  defp cache_dams_stats(dams, hourly_periods, daily_periods, monthly_periods, usage_types) do
    Enum.each(hourly_periods, fn period ->
      Enum.each(dams, fn dam ->
        Dams.hourly_stats(dam.site_id, period)
      end)
    end)

    Enum.each(usage_types, fn ut -> Dams.current_storage(ut) end)

    Enum.each(daily_periods, fn period ->
      Enum.each(dams, fn dam ->
        Dams.daily_stats(dam.site_id, period)
        Dams.get(dam.site_id)
        Dams.current_storage(dam.site_id)
      end)
    end)

    Enum.each(monthly_periods, fn period ->
      Enum.each(dams, fn dam ->
        Dams.monthly_stats(dam.site_id, period)
      end)
    end)
  end

  defp cache_basin_stats(basin_ids, daily_periods, monthly_periods, usage_types) do
    Basins.monthly_stats_for_basins()
    Enum.each(usage_types, fn ut -> Basins.summary_stats(ut) end)

    Enum.each(basin_ids, fn basin_id ->
      Enum.each(usage_types, fn ut -> Basins.summary_stats(basin_id, ut) end)
    end)

    Enum.each(daily_periods, fn period ->
      Enum.each(basin_ids, fn basin_id ->
        Enum.each(usage_types, fn ut -> Basins.daily_stats_for_basin(basin_id, ut, period) end)
      end)
    end)

    Enum.each(monthly_periods, fn period ->
      Enum.each(basin_ids, fn basin_id ->
        Enum.each(usage_types, fn ut -> Basins.monthly_stats_for_basin(basin_id, ut, period) end)
      end)
    end)
  end

  defp cache_discharge_stats(dams, hourly_periods, daily_periods, monthly_periods) do
    Enum.each(hourly_periods, fn period ->
      Enum.each(dams, fn dam ->
        Dams.discharge_stats(dam.site_id, period, :week)
      end)
    end)

    Enum.each(daily_periods, fn period ->
      Enum.each(dams, fn dam ->
        Dams.discharge_stats(dam.site_id, period, :month)
      end)
    end)

    Enum.each(monthly_periods, fn period ->
      Enum.each(dams, fn dam ->
        Dams.discharge_monthly_stats(dam.site_id, period)
      end)
    end)
  end

  defp get_usage_types_combinations(usage_types) do
    ut_length = Enum.count(usage_types)

    Enum.reduce(1..ut_length, [], fn x, acc -> Enum.concat(acc, combinations(usage_types, x)) end)
  end

  defp combinations(_list, 0), do: [[]]
  defp combinations([], _num), do: []

  defp combinations([head | tail], num) do
    Enum.map(combinations(tail, num - 1), &[head | &1]) ++
      combinations(tail, num)
  end
end
