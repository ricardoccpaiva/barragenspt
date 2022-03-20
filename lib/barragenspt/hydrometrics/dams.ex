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
              key: "daily_stats_for_site_#{dam.site_id}-#{period}",
              ttl: @ttl
            )
  def daily_stats(dam, period \\ 2) do
    historic_values =
      Repo.all(
        from(b in DailyAverageStorageBySite,
          where: b.site_id == ^dam.site_id
        )
      )

    query =
      from(dp in DataPoint,
        join: d in Dam,
        on: d.site_id == dp.site_id,
        where:
          dp.param_name == "volume_last_hour" and
            dp.site_id == ^dam.site_id and
            dp.colected_at >= ^query_limit(period, :month),
        group_by: [
          :site_id,
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
        basin_id: dam.site_id,
        value: value |> Decimal.mult(100) |> Decimal.round(1) |> Decimal.to_float(),
        date: date,
        basin: "Observado"
      }
    end)
    |> Stream.map(fn m ->
      hdata =
        build_average_data(
          historic_values,
          :site_id,
          dam.site_id,
          m.date,
          "#{m.date.day}-#{m.date.month}"
        )

      [m, hdata]
    end)
    |> Enum.to_list()
    |> List.flatten()
    |> Enum.sort(&(Timex.compare(&1.date, &2.date) < 0))
  end

  @decorate cacheable(cache: Cache, key: "for_site_#{dam.site_id}-#{period}", ttl: @ttl)
  def monthly_stats(dam, period \\ 2) do
    historic_values =
      Repo.all(
        from(b in MonthlyAverageStorageBySite,
          where: b.site_id == ^dam.site_id
        )
      )

    query =
      from(dp in DataPoint,
        join: d in Dam,
        on: d.site_id == dp.site_id,
        where:
          dp.param_name == "volume_last_day_month" and
            dp.site_id == ^dam.site_id and
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
        basin_id: dam.site_id,
        value: value |> Decimal.mult(100) |> Decimal.round(1) |> Decimal.to_float(),
        date: date,
        basin: "Observado"
      }
    end)
    |> Stream.map(fn m ->
      hdata = build_average_data(historic_values, :site_id, dam.site_id, m.date, m.date.month)

      [m, hdata]
    end)
    |> Enum.to_list()
    |> List.flatten()
    |> Enum.sort(&(Timex.compare(&1.date, &2.date) < 0))
  end

  def current_storage(site_id) do
    Repo.one(
      from(b in SiteCurrentStorage,
        where: b.site_id == ^site_id,
        select: %{
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
