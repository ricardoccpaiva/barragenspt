defmodule Barragenspt.Hydrometrics.Basins do
  import Ecto.Query

  alias Barragenspt.Hydrometrics.{
    MonthlyAverageStorageByBasin,
    DailyAverageStorageByBasin,
    DailyAverageStorageBySite,
    SiteCurrentStorage,
    DataPoint,
    BasinStorage,
    Basin,
    Dam
  }

  use Nebulex.Caching
  alias Barragenspt.Cache
  alias Barragenspt.Repo

  @ttl :timer.hours(1)

  @decorate cacheable(
              cache: Cache,
              key: "basins.daily_stats_for_basin_#{id}_#{period}",
              ttl: @ttl
            )
  def daily_stats_for_basin(id, period \\ 1) do
    historic_values =
      Repo.all(
        from(b in DailyAverageStorageByBasin,
          where: b.basin_id == ^id
        )
      )

    query =
      from(dp in DataPoint,
        join: d in Dam,
        on: d.basin_id == dp.basin_id,
        where:
          dp.param_name == "volume_last_hour" and
            dp.basin_id == ^id and
            dp.colected_at >= ^query_limit(period, :month),
        group_by: [
          :basin_id,
          fragment("DATE(?)", dp.colected_at)
        ],
        select: {
          sum(dp.value) /
            fragment(
              "sum((? -> ? ->> ?)::int)",
              d.metadata,
              "Albufeira",
              "Capacidade total (dam3)"
            ),
          fragment("DATE(?)", dp.colected_at)
        }
      )

    query
    |> Repo.all()
    |> Stream.map(fn {value, date} ->
      %{
        basin_id: id,
        value: value |> Decimal.mult(100) |> Decimal.round(1) |> Decimal.to_float(),
        date: date,
        basin: "Observado"
      }
    end)
    |> Stream.map(fn m ->
      hdata =
        build_average_data(
          historic_values,
          :basin_id,
          id,
          m.date,
          "#{m.date.day}-#{m.date.month}"
        )

      [m, hdata]
    end)
    |> Enum.to_list()
    |> List.flatten()
    |> Enum.sort(&(Timex.compare(&1.date, &2.date) < 0))
  end

  @decorate cacheable(
              cache: Cache,
              key: "basins.monthly_stats_for_basin_#{id}_#{period}",
              ttl: @ttl
            )
  def monthly_stats_for_basin(id, period \\ 2) do
    historic_values =
      Repo.all(
        from(b in MonthlyAverageStorageByBasin,
          where: b.basin_id == ^id
        )
      )

    query =
      from(dp in DataPoint,
        join: d in Dam,
        on: d.basin_id == dp.basin_id,
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
          sum(dp.value) /
            fragment(
              "sum((? -> ? ->> ?)::int)",
              d.metadata,
              "Albufeira",
              "Capacidade total (dam3)"
            ),
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
        basin_id: id,
        value: value |> Decimal.mult(100) |> Decimal.round(1) |> Decimal.to_float(),
        date: date,
        basin: "Observado"
      }
    end)
    |> Stream.map(fn m ->
      hdata = build_average_data(historic_values, :basin_id, id, m.date, m.date.month)

      [m, hdata]
    end)
    |> Enum.to_list()
    |> List.flatten()
    |> Enum.sort(&(Timex.compare(&1.date, &2.date) < 0))
  end

  @decorate cacheable(cache: Cache, key: "basins.monthly_stats_for_basins", ttl: @ttl)
  def monthly_stats_for_basins() do
    query =
      from(dp in DataPoint,
        join: b in Basin,
        on: dp.basin_id == b.id,
        where:
          dp.param_name == "volume_last_day_month" and
            dp.colected_at >= ^query_limit_all_basins() and
            dp.colected_at <= ^end_of_previous_month(),
        group_by: [
          b.id,
          b.name,
          fragment(
            "DATE( date_trunc( 'month', ?) + interval '1 month' - interval '1 day')",
            dp.colected_at
          )
        ],
        select: {
          b.id,
          b.name,
          fragment(
            "sum(value) / (SELECT sum((metadata  -> 'Albufeira' ->> 'Capacidade total (dam3)')::int) from dam d where basin_id = ?)",
            b.id
          ),
          fragment(
            "DATE( date_trunc( 'month', ?) + interval '1 month' - interval '1 day')",
            dp.colected_at
          )
        }
      )

    query
    |> Repo.all()
    |> Enum.map(fn {basin_id, basin_name, value, date} ->
      %{
        basin_id: basin_id,
        value: value |> Decimal.mult(100) |> Decimal.round(1) |> Decimal.to_float(),
        date: date,
        basin: basin_name
      }
    end)
    |> Enum.sort(&(Timex.compare(&1.date, &2.date) < 0))
  end

  @decorate cacheable(cache: Cache, key: "basins.summary_stats", ttl: @ttl)
  def summary_stats() do
    query =
      from(d in DailyAverageStorageByBasin,
        join: b in BasinStorage,
        on: d.basin_id == b.id,
        where: d.period == ^"#{Timex.now().day}-#{Timex.now().month}",
        select: {
          d.basin_id,
          b.name,
          fragment("round(?, 1)", b.current_storage),
          fragment("round(?, 1)", d.value)
        }
      )

    Repo.all(query)
  end

  @decorate cacheable(cache: Cache, key: "basins.summary_stats_#{id}", ttl: @ttl)
  def summary_stats(id) do
    query =
      from(d in DailyAverageStorageBySite,
        join: b in SiteCurrentStorage,
        on: d.site_id == b.site_id,
        where: d.period == ^"#{Timex.now().day}-#{Timex.now().month}" and b.basin_id == ^id,
        select: %{
          site_id: d.site_id,
          site_name: b.site_name,
          basin_name: b.basin_name,
          current_storage: fragment("round(?, 1)", b.current_storage),
          average_storage: fragment("round(?, 1)", d.value)
        }
      )

    Repo.all(query)
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

  defp build_average_data(historic_values, field, id, date, period) do
    hval =
      Enum.find(historic_values, fn h ->
        Map.get(h, field) == id and h.period == period
      end)

    hval = hval || %{value: Decimal.new("0.0")}

    %{
      basin_id: "Média",
      value: hval.value |> Decimal.round(1) |> Decimal.to_float(),
      date: date,
      basin: "Média"
    }
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

  defp query_limit_all_basins do
    Timex.now()
    |> Timex.end_of_month()
    |> Timex.shift(years: -2)
    |> Timex.beginning_of_month()
    |> Timex.to_naive_datetime()
  end
end
