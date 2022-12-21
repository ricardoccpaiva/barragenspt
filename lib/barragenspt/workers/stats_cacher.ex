defmodule Barragenspt.Workers.StatsCacher do
  use Oban.Worker, queue: :stats_cacher
  alias Barragenspt.Hydrometrics.Dams
  alias Barragenspt.Hydrometrics.Basins
  require Logger

  @impl Oban.Worker
  def perform(_args) do
    Barragenspt.Cache.flush()

    dams = Dams.all()

    basin_ids =
      dams
      |> Enum.uniq_by(fn %{basin_id: basin_id} -> basin_id end)
      |> Enum.map(fn %{basin_id: basin_id} -> basin_id end)

    hourly_periods = [1, 2]
    daily_periods = [1, 6]
    monthly_periods = [2, 5, 10, 50]

    cache_basin_stats(basin_ids, daily_periods, monthly_periods)
    cache_dams_stats(dams, daily_periods, monthly_periods, hourly_periods)
  end

  defp cache_dams_stats(dams, daily_periods, monthly_periods, hourly_periods) do
    Dams.current_storage()

    Enum.each(hourly_periods, fn period ->
      Enum.each(dams, fn dam ->
        Dams.hourly_stats(dam.site_id, period)
      end)
    end)

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

  defp cache_basin_stats(basin_ids, daily_periods, monthly_periods) do
    Basins.monthly_stats_for_basins()
    Basins.summary_stats()

    Enum.each(basin_ids, fn basin_id ->
      Basins.summary_stats(basin_id)
    end)

    Enum.each(daily_periods, fn period ->
      Enum.each(basin_ids, fn basin_id ->
        Basins.daily_stats_for_basin(basin_id, period)
      end)
    end)

    Enum.each(monthly_periods, fn period ->
      Enum.each(basin_ids, fn basin_id ->
        Basins.monthly_stats_for_basin(basin_id, period)
      end)
    end)
  end
end
