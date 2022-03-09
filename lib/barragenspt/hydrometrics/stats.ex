defmodule Barragenspt.Hydrometrics.Stats do
  import Ecto.Query
  alias Barragenspt.Hydrometrics.DailyAverageStorageByBasin
  alias Barragenspt.Hydrometrics.DailyAverageStorageBySite
  alias Barragenspt.Hydrometrics.BasinStorage
  alias Barragenspt.Hydrometrics.SiteCurrentStorage
  use Nebulex.Caching
  alias Barragenspt.Cache

  @ttl :timer.hours(24)

  @decorate cacheable(cache: Cache, key: "for_basin_#{id}-#{period}", ttl: @ttl)
  def for_basin(id, period \\ 2) do
    query =
      from(b in Barragenspt.Hydrometrics.MonthlyAverageStorageByBasin,
        where: b.basin_id == ^id
      )

    historic_values = Barragenspt.Repo.all(query)

    query =
      from(dp in Barragenspt.Hydrometrics.DataPoint,
        where:
          dp.param_name == "volume_last_day_month" and
            dp.basin_id == ^id and
            dp.colected_at >= ^query_limit(period),
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
            "'01-' || extract(month from ?) || '-' || extract(year from ?) as dt",
            dp.colected_at,
            dp.colected_at
          )
        }
      )

    query
    |> Barragenspt.Repo.all()
    |> Enum.map(fn {value, date} ->
      rounded_value = value |> Decimal.round(1) |> Decimal.to_float()

      %{ts: ts, dt: dt} = parse_date(date)

      %{basin_id: id, value: rounded_value, timestamp: ts, date: dt, basin: "Observado"}
    end)
    |> Enum.map(fn m ->
      hval =
        Enum.find(historic_values, fn h ->
          h.basin_id == id and h.period == Timex.from_unix(m.timestamp).month
        end)

      [
        m,
        %{
          basin_id: "Média",
          value: hval.value |> Decimal.round(1) |> Decimal.to_float(),
          timestamp: m.timestamp,
          date: m.date,
          basin: "Média"
        }
      ]
    end)
    |> List.flatten()
    |> Enum.sort(&(&1.timestamp < &2.timestamp))
    |> Enum.map(fn m -> Map.drop(m, [:timestamp]) end)
  end

  @decorate cacheable(cache: Cache, key: "for_basins", ttl: @ttl)
  def for_basins() do
    query =
      from(dp in Barragenspt.Hydrometrics.DataPoint,
        join: b in Barragenspt.Hydrometrics.Basin,
        on: dp.basin_id == b.id,
        where:
          dp.param_name == "volume_last_day_month" and
            dp.colected_at >= ^query_limit_all_basins(),
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
            "'01-' || extract(month from ?) || '-' || extract(year from ?) as dt",
            dp.colected_at,
            dp.colected_at
          )
        }
      )

    query
    |> Barragenspt.Repo.all()
    |> Enum.map(fn {basin_id, basin_name, value, date} ->
      rounded_value = value |> Decimal.round(1) |> Decimal.to_float()

      %{ts: ts, dt: dt} = parse_date(date)

      %{basin_id: basin_id, value: rounded_value, timestamp: ts, date: dt, basin: basin_name}
    end)
    |> Enum.sort(&(&1.timestamp < &2.timestamp))
    |> Enum.map(fn m -> Map.drop(m, [:timestamp]) end)
  end

  @decorate cacheable(cache: Cache, key: "for_site_#{dam.site_id}-#{period}", ttl: @ttl)
  def for_site(dam, period \\ 2) do
    query =
      from(b in Barragenspt.Hydrometrics.MonthlyAverageStorageBySite,
        where: b.site_id == ^dam.site_id
      )

    historic_values = Barragenspt.Repo.all(query)

    query =
      from(dp in Barragenspt.Hydrometrics.DataPoint,
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
            "'01-' || extract(month from ?) || '-' || extract(year from ?) as dt",
            dp.colected_at,
            dp.colected_at
          )
        }
      )

    query
    |> Barragenspt.Repo.all()
    |> Enum.map(fn {value, date} ->
      rounded_value = value |> Decimal.round(1) |> Decimal.to_float()

      %{ts: ts, dt: dt} = parse_date(date)

      %{
        basin_id: dam.site_id,
        value: rounded_value,
        timestamp: ts,
        date: dt,
        basin: "Observado"
      }
    end)
    |> Enum.map(fn m ->
      hval =
        Enum.find(historic_values, fn h ->
          h.site_id == dam.site_id and h.period == Timex.from_unix(m.timestamp).month
        end)

      [
        m,
        %{
          basin_id: "Média",
          value: hval.value |> Decimal.round(1) |> Decimal.to_float(),
          timestamp: m.timestamp,
          date: m.date,
          basin: "Média"
        }
      ]
    end)
    |> List.flatten()
    |> Enum.sort(&(&1.timestamp < &2.timestamp))
    |> Enum.map(fn m -> Map.drop(m, [:timestamp]) end)
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

  defp query_limit() do
    query_limit(2)
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
