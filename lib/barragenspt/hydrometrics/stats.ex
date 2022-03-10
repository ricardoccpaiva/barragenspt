defmodule Barragenspt.Hydrometrics.Stats do
  import Ecto.Query

  alias Barragenspt.Hydrometrics.{
    DailyAverageStorageByBasin,
    DailyAverageStorageBySite,
    MonthlyAverageStorageByBasin,
    MonthlyAverageStorageBySite,
    BasinStorage,
    SiteCurrentStorage,
    DataPoint,
    Basin
  }

  use Nebulex.Caching
  alias Barragenspt.Cache
  alias Barragenspt.Repo

  @ttl :timer.hours(24)

  @decorate cacheable(cache: Cache, key: "monthly_for_basin_#{id}_#{period}", ttl: @ttl)
  def monthly_for_basin(id, period \\ 2) do
    historic_values =
      Repo.all(
        from(b in MonthlyAverageStorageByBasin,
          where: b.basin_id == ^id
        )
      )

    query =
      from(dp in DataPoint,
        where:
          dp.param_name == "volume_last_day_month" and
            dp.basin_id == ^id and
            dp.colected_at >= ^query_limit(period) and dp.colected_at <= ^end_of_previous_month(),
        group_by: [
          :basin_id,
          fragment("extract(month from ?)", dp.colected_at),
          fragment("extract(year from ?)", dp.colected_at)
        ],
        select: {
          fragment(
            "sum(value) / (SELECT sum((metadata  -> 'Albufeira' ->> 'Capacidade total (dam3)')::int) from dam d where basin_id = ?) * 100",
            ^id
          ),
          fragment(
            "cast(extract(month from ?) as int) as month",
            dp.colected_at
          ),
          fragment(
            "cast(extract(year from ?) as int) as year",
            dp.colected_at
          )
        }
      )

    query
    |> Repo.all()
    |> Stream.map(fn {value, month, year} ->
      days = Timex.days_in_month(year, month)

      {:ok, parsed_date} = Timex.parse("#{days}-#{month}-#{year}", "{D}-{M}-{YYYY}")

      %{basin_id: id, value: value, date: parsed_date, basin: "Observado"}
    end)
    |> Stream.map(fn m ->
      hdata = build_historic_data_map(historic_values, :basin_id, id, m.date)

      [m, hdata]
    end)
    |> Enum.to_list()
    |> List.flatten()
    |> Enum.sort(&(Timex.compare(&1.date, &2.date) < 0))
  end

  @decorate cacheable(cache: Cache, key: "monthly_for_basins", ttl: @ttl)
  def monthly_for_basins() do
    query =
      from(dp in DataPoint,
        join: b in Basin,
        on: dp.basin_id == b.id,
        where:
          dp.param_name == "volume_last_day_month" and
            dp.colected_at >= ^query_limit_all_basins() and
            dp.colected_at <= ^end_of_previous_month(),
        group_by: [
          :basin_id,
          b.name,
          fragment("extract(month from ?)", dp.colected_at),
          fragment("extract(year from ?)", dp.colected_at)
        ],
        select: {
          dp.basin_id,
          b.name,
          fragment(
            "(sum(value) / (SELECT sum((metadata  -> 'Albufeira' ->> 'Capacidade total (dam3)')::int) from dam d where basin_id = ?)) * 100",
            dp.basin_id
          ),
          fragment(
            "cast(extract(month from ?) as int) as month",
            dp.colected_at
          ),
          fragment(
            "cast(extract(year from ?) as int) as year",
            dp.colected_at
          )
        }
      )

    query
    |> Repo.all()
    |> Enum.map(fn {basin_id, basin_name, value, month, year} ->
      days = Timex.days_in_month(year, month)

      {:ok, parsed_date} = Timex.parse("#{days}-#{month}-#{year}", "{D}-{M}-{YYYY}")

      %{
        basin_id: basin_id,
        value: value |> Decimal.round(1) |> Decimal.to_float(),
        date: parsed_date,
        basin: basin_name
      }
    end)
    |> Enum.sort(&(Timex.compare(&1.date, &2.date) < 0))
  end

  @decorate cacheable(cache: Cache, key: "for_site_#{dam.site_id}-#{period}", ttl: @ttl)
  def for_site(dam, period \\ 2) do
    historic_values =
      Repo.all(
        from(b in MonthlyAverageStorageBySite,
          where: b.site_id == ^dam.site_id
        )
      )

    query =
      from(dp in DataPoint,
        where:
          dp.param_name == "volume_last_day_month" and
            dp.site_id == ^dam.site_id and
            dp.colected_at >= ^query_limit(period),
        group_by: [
          :site_id,
          fragment("extract(month from ?)", dp.colected_at),
          fragment("extract(year from ?)", dp.colected_at)
        ],
        select: {
          fragment(
            "sum(value) / (SELECT sum((metadata  -> 'Albufeira' ->> 'Capacidade total (dam3)')::int) from dam d where site_id = ?) * 100",
            ^dam.site_id
          ),
          fragment(
            "cast(extract(month from ?) as int) as month",
            dp.colected_at
          ),
          fragment(
            "cast(extract(year from ?) as int) as year",
            dp.colected_at
          )
        }
      )

    query
    |> Repo.all()
    |> Stream.map(fn {value, month, year} ->
      days = Timex.days_in_month(year, month)

      {:ok, parsed_date} = Timex.parse("#{days}-#{month}-#{year}", "{D}-{M}-{YYYY}")

      %{
        basin_id: dam.site_id,
        value: value |> Decimal.round(1) |> Decimal.to_float(),
        date: parsed_date,
        basin: "Observado"
      }
    end)
    |> Stream.map(fn m ->
      hdata = build_historic_data_map(historic_values, :site_id, dam.site_id, m.date)

      [m, hdata]
    end)
    |> Enum.to_list()
    |> List.flatten()
    |> Enum.sort(&(Timex.compare(&1.date, &2.date) < 0))
  end

  @decorate cacheable(cache: Cache, key: "basins_summary", ttl: @ttl)
  def basins_summary() do
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

    Barragenspt.Repo.all(query)
  end

  @decorate cacheable(cache: Cache, key: "basin_summary_#{id}", ttl: @ttl)
  def basin_summary(id) do
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

    Barragenspt.Repo.all(query)
  end

  defp parse_date(date) do
    {:ok, parsed_date} = Timex.parse(date, "{D}-{M}-{YYYY}")

    ts = Timex.to_unix(parsed_date)
    dt = Timex.format!(parsed_date, "{YYYY}-{M}-{D}")

    %{ts: ts, dt: dt}
  end

  defp build_historic_data_map(historic_values, field, id, date) do
    hval =
      Enum.find(historic_values, fn h ->
        h[field] == id and h.period == date.month
      end)

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

  defp query_limit_all_basins do
    Timex.now()
    |> Timex.end_of_month()
    |> Timex.shift(years: -2)
    |> Timex.beginning_of_month()
    |> Timex.to_naive_datetime()
  end
end
