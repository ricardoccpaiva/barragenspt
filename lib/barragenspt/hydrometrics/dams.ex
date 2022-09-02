defmodule Barragenspt.Hydrometrics.Dams do
  import Ecto.Query
  use Nebulex.Caching

  alias Barragenspt.Geo.Coordinates

  alias Barragenspt.Hydrometrics.{
    MonthlyAverageStorageBySite,
    DailyAverageStorageBySite,
    SiteCurrentStorage,
    DataPoint,
    Dam
  }

  alias Barragenspt.Repo
  alias Barragenspt.Cache

  @ttl :timer.hours(1)

  @decorate cacheable(
              cache: Cache,
              key: "dam_#{id}",
              ttl: @ttl
            )
  def get(id) do
    Barragenspt.Repo.one!(from(d in Dam, where: d.site_id == ^id))
  end

  def all do
    Repo.all(from(b in Dam))
  end

  def bounding_box(basin_id) do
    query = from(d in Dam, where: d.basin_id == ^basin_id)

    query
    |> Barragenspt.Repo.all()
    |> Stream.map(fn dam -> Coordinates.from_dam(dam) end)
    |> Stream.map(fn %{lat: lat, lon: lon} -> [lon, lat] end)
    |> Enum.to_list()
    |> Geocalc.bounding_box_for_points()
  end

  @decorate cacheable(
              cache: Cache,
              key: "daily_stats_for_site_#{id}-#{period}",
              ttl: @ttl
            )
  def daily_stats(id, period \\ 2) do
    historic_values =
      Repo.all(
        from(b in DailyAverageStorageBySite,
          where: b.site_id == ^id
        )
      )

    query =
      from(dp in DataPoint,
        join: d in Dam,
        on: d.site_id == dp.site_id,
        where:
          dp.param_name == "volume_last_hour" and
            dp.site_id == ^id and
            dp.colected_at >= ^query_limit(period, :month),
        group_by: [
          :site_id,
          fragment("DATE(?)", dp.colected_at)
        ],
        select: {
          sum(dp.value) /
            fragment(
              "sum((? -> ? ->> ?)::decimal)",
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
    |> Stream.reject(fn %{value: value} -> value > 100 end)
    |> Stream.map(fn m ->
      hdata =
        build_average_data(
          historic_values,
          :site_id,
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

  @decorate cacheable(cache: Cache, key: "for_site_#{id}-#{period}", ttl: @ttl)
  def monthly_stats(id, period \\ 2) do
    historic_values =
      Repo.all(
        from(b in MonthlyAverageStorageBySite,
          where: b.site_id == ^id
        )
      )

    query =
      from(dp in DataPoint,
        join: d in Dam,
        on: d.site_id == dp.site_id,
        where:
          dp.param_name == "volume_last_day_month" and
            dp.site_id == ^id and
            dp.colected_at >= ^query_limit(period),
        group_by: [
          :site_id,
          fragment(
            "DATE( date_trunc( 'month', ?) + interval '1 month' - interval '1 day')",
            dp.colected_at
          )
        ],
        select: {
          sum(dp.value) /
            fragment(
              "sum((? -> ? ->> ?)::decimal)",
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
    |> Stream.reject(fn %{value: value} -> value > 100 end)
    |> Stream.map(fn m ->
      hdata = build_average_data(historic_values, :site_id, id, m.date, m.date.month)

      [m, hdata]
    end)
    |> Enum.to_list()
    |> List.flatten()
    |> Enum.sort(&(Timex.compare(&1.date, &2.date) < 0))
  end

  @decorate cacheable(cache: Cache, key: "dam_current_storage_#{site_id}", ttl: @ttl)
  def current_storage(site_id) do
    Repo.one(
      from(b in SiteCurrentStorage,
        where: b.site_id == ^site_id and b.current_storage <= 100,
        select: %{
          current_storage: fragment("round(?, 1)", b.current_storage)
        }
      )
    )
  end

  @decorate cacheable(cache: Cache, key: "dams_current_storage", ttl: @ttl)
  def current_storage() do
    Repo.all(
      from(b in SiteCurrentStorage,
        where: b.current_storage <= 100,
        select: %{
          basin_id: b.basin_id,
          basin_name: b.basin_name,
          site_id: b.site_id,
          site_name: b.site_name,
          current_storage: fragment("round(?, 1)", b.current_storage)
        }
      )
    )
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
