defmodule Barragenspt.Hydrometrics.Basins do
  import Ecto.Query

  alias Barragenspt.Models.Hydrometrics.{
    DataPoint,
    BasinStorage,
    Basin,
    Dam,
    DamUsage
  }

  alias Barragenspt.Hydrometrics.Dams

  use Nebulex.Caching
  alias Barragenspt.Cache
  alias Barragenspt.Repo
  require Logger

  @ttl :timer.hours(1)

  @decorate cacheable(
              cache: Cache,
              key: "basins.daily_stats_for_basin_#{id}_#{Enum.join(usage_types, "-")}_#{period}",
              ttl: @ttl
            )
  def daily_stats_for_basin(id, usage_types, period \\ 1) do
    historic_values =
      Repo.all(
        from(b in subquery(daily_average_storage_by_basin_query(id, usage_types)),
          where: b.basin_id == ^id
        )
      )

    subquery =
      from(dp in DataPoint,
        join: d in Dam,
        on: d.basin_id == dp.basin_id and d.site_id == dp.site_id,
        where:
          dp.param_name == "volume_last_hour" and
            dp.basin_id == ^id and
            dp.colected_at >= ^query_limit(period, :month),
        select: %{
          site_id: d.site_id,
          basin_id: d.basin_id,
          value: dp.value,
          total_capacity: d.total_capacity,
          period: fragment("DATE(?)", dp.colected_at)
        }
      )

    query =
      from q in subquery(subquery),
        group_by: [
          q.basin_id,
          q.period
        ],
        order_by: [q.period, q.basin_id],
        select: {
          sum(q.value) / sum(q.total_capacity),
          q.period
        }

    query
    |> Repo.all()
    |> Stream.map(fn {value, date} ->
      %{
        observed_value: value |> Decimal.mult(100) |> Decimal.round(2) |> Decimal.to_float(),
        historical_average:
          historic_values
          |> Enum.find(fn h -> h.period == "#{date.day}-#{date.month}" end)
          |> Map.get(:value)
          |> Decimal.round(2)
          |> Decimal.to_float(),
        date: date
      }
    end)
    |> Enum.to_list()
    |> Enum.sort(&(Timex.compare(&1.date, &2.date) < 0))
  end

  @decorate cacheable(
              cache: Cache,
              key:
                "basins.monthly_stats_for_basin_#{id}_#{Enum.join(usage_types, "-")}_#{period}",
              ttl: @ttl
            )
  def monthly_stats_for_basin(id, usage_types, period \\ 2) do
    historic_values =
      Repo.all(from(b in subquery(monthly_average_storage_by_basin_query(id, usage_types))))

    query =
      from(dp in DataPoint,
        join: d in Dam,
        on: d.basin_id == dp.basin_id and dp.site_id == d.site_id,
        where:
          dp.param_name == "volume_last_day_month" and
            dp.basin_id == ^id and
            dp.colected_at >= ^query_limit(period) and dp.colected_at <= ^end_of_previous_month(),
        group_by: [
          :basin_id,
          fragment(
            "DATE( date_trunc( 'month', ?) + interval '1 month' - interval '1 day')",
            dp.colected_at
          )
        ],
        select: {
          sum(dp.value) / sum(d.total_capacity),
          fragment(
            "DATE( date_trunc( 'month', ?) + interval '1 month' - interval '1 day')",
            dp.colected_at
          )
        }
      )

    query
    |> Repo.all()
    |> Stream.map(fn {value, date} ->
      %{
        observed_value: value |> Decimal.mult(100) |> Decimal.round(2) |> Decimal.to_float(),
        historical_average:
          historic_values
          |> Enum.find(fn h -> h.period == date.month end)
          |> Map.get(:value)
          |> Decimal.round(2)
          |> Decimal.to_float(),
        date: date
      }
    end)
    |> Enum.to_list()
    |> Enum.sort(&(Timex.compare(&1.date, &2.date) < 0))
  end

  @decorate cacheable(
              cache: Cache,
              key: "basins.summary_stats_#{Enum.join(usage_types, "-")}",
              ttl: @ttl
            )
  def summary_stats(usage_types) do
    query =
      from(d in subquery(daily_average_storage_by_basin_query(nil, usage_types)),
        join: b in subquery(basin_current_storage_query(usage_types)),
        on: d.basin_id == b.id,
        where:
          d.period == ^"#{Timex.now().day}-#{Timex.now().month}" and b.current_storage <= 100 and
            d.value <= 100,
        select: %{
          id: d.basin_id,
          name: b.name,
          observed_value: fragment("round(?, 1)", b.current_storage),
          historical_average: fragment("round(?, 1)", d.value)
        }
      )

    Repo.all(query)
  end

  @decorate cacheable(
              cache: Cache,
              key: "basins.summary_stats_#{id}_#{Enum.join(usage_types, "-")}",
              ttl: @ttl
            )
  def summary_stats(id, usage_types) do
    filter =
      dynamic(
        [d, b, _du, dd],
        d.period == ^"#{Timex.now().day}-#{Timex.now().month}" and b.basin_id == ^id and
          b.value <= dd.total_capacity and d.value <= dd.total_capacity
      )

    filter =
      if usage_types != [] do
        dynamic([_dp, _d, du, dd], ^filter and du.usage_name in ^usage_types)
      else
        filter
      end

    query =
      from(d in subquery(Dams.daily_average_storage_by_site_query(id, usage_types)),
        join: b in subquery(Dams.sites_current_storage_query(id, usage_types)),
        on: d.site_id == b.site_id,
        join: du in DamUsage,
        on: b.site_id == du.site_id,
        join: dd in Dam,
        on: d.site_id == dd.site_id,
        where: ^filter,
        select: %{
          site_id: d.site_id,
          site_name: dd.name,
          basin_name: dd.basin,
          observed_value: fragment("round((?/?)*100, 1)", b.value, dd.total_capacity),
          historical_average: fragment("round(?, 1)", d.value),
          colected_at: b.colected_at,
          total_capacity: dd.total_capacity
        }
      )

    query
    |> distinct(true)
    |> Repo.all()
  end

  def get_storage(id) do
    Repo.one!(from(b in BasinStorage, where: b.id == ^id))
  end

  def get(id) do
    Repo.one(from(b in Basin, where: b.id == ^id))
  end

  def all do
    Repo.all(from(b in Basin))
  end

  defp daily_average_storage_by_basin_query(basin_id, usage_types) do
    filter = dynamic([dp], dp.param_name == "volume_last_hour")

    filter =
      if usage_types != [] do
        dynamic([_dp, _d, du], ^filter and du.usage_name in ^usage_types)
      else
        filter
      end

    filter =
      if basin_id != nil do
        dynamic([_dp, d, _du], ^filter and d.basin_id == ^basin_id)
      else
        filter
      end

    subquery =
      from(dp in DataPoint,
        join: d in Dam,
        on: dp.site_id == d.site_id,
        join: du in DamUsage,
        on: d.site_id == du.site_id,
        where: ^filter,
        order_by: dp.colected_at,
        select: %{
          dam_code: dp.dam_code,
          basin_id: dp.basin_id,
          site_id: dp.site_id,
          average: dp.value / d.total_capacity,
          period:
            fragment(
              "EXTRACT(day FROM ?) || '-' || EXTRACT(month FROM ?)",
              dp.colected_at,
              dp.colected_at
            )
        }
      )

    from q in subquery(subquery),
      group_by: [
        q.period,
        q.basin_id
      ],
      order_by: [q.period, q.basin_id],
      select: %{
        period: q.period,
        basin_id: q.basin_id,
        value: avg(q.average) * 100
      }
  end

  defp monthly_average_storage_by_basin_query(basin_id, usage_types) do
    filter = dynamic([dp], dp.param_name == "volume_last_day_month")

    filter =
      if usage_types != [] do
        dynamic([_dp, _d, du], ^filter and du.usage_name in ^usage_types)
      else
        filter
      end

    filter =
      if basin_id != nil do
        dynamic([_dp, d, _du], ^filter and d.basin_id == ^basin_id)
      else
        filter
      end

    subquery =
      from(dp in DataPoint,
        join: d in Dam,
        on: dp.site_id == d.site_id,
        join: du in DamUsage,
        on: d.site_id == du.site_id,
        where: ^filter,
        order_by: dp.colected_at,
        select: %{
          dam_code: dp.dam_code,
          basin_id: dp.basin_id,
          site_id: dp.site_id,
          average: dp.value / d.total_capacity,
          period: fragment("EXTRACT(month FROM ?)::integer", dp.colected_at)
        }
      )

    from q in subquery(subquery),
      group_by: [
        q.period,
        q.basin_id
      ],
      order_by: [q.period, q.basin_id],
      select: %{
        period: q.period,
        basin_id: q.basin_id,
        value: avg(q.average) * 100
      }
  end

  defp basin_current_storage_query(usage_types) do
    from(dp in subquery(Dams.sites_current_storage_query(nil, usage_types)),
      join: d in Dam,
      on: d.site_id == dp.site_id,
      group_by: [d.basin_id, d.basin],
      select: %{
        id: d.basin_id,
        name: d.basin,
        current_storage: sum(dp.value) / sum(d.total_capacity) * 100
      }
    )
  end

  defp end_of_previous_month() do
    Timex.now()
    |> Timex.beginning_of_month()
    |> Timex.shift(months: -1)
    |> Timex.end_of_month()
    |> Timex.to_naive_datetime()
  end

  defp query_limit(period) do
    Timex.now()
    |> Timex.end_of_month()
    |> Timex.shift(years: period * -1)
    |> Timex.beginning_of_month()
    |> Timex.to_naive_datetime()
  end

  defp query_limit(period, :month) do
    Timex.now()
    |> Timex.end_of_month()
    |> Timex.shift(months: period * -1)
    |> Timex.beginning_of_month()
    |> Timex.to_naive_datetime()
  end
end
