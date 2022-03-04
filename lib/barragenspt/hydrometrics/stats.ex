defmodule Barragenspt.Hydrometrics.Stats do
  import Ecto.Query

  def for_basin(%{id: basin_id, name: basin_name}) do
    query =
      from(dp in Barragenspt.Hydrometrics.DataPoint,
        where:
          dp.param_name == "volume_last_day_month" and
            dp.basin_id == ^basin_id and
            dp.colected_at >= ^query_limit(),
        group_by: [
          :basin_id,
          fragment("extract(month from ?)", dp.colected_at),
          fragment("extract(year from ?)", dp.colected_at)
        ],
        select: {
          fragment(
            "sum(value) / (SELECT sum((metadata  -> 'Albufeira' ->> 'Capacidade total (dam3)')::int) from dam d where basin_id = ?) * 100",
            ^basin_id
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

      %{basin_id: basin_id, value: rounded_value, timestamp: ts, date: dt, basin: basin_name}
    end)
    |> Enum.sort(&(&1.timestamp < &2.timestamp))
    |> Enum.map(fn m -> Map.drop(m, [:timestamp]) end)
  end

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

  def for_site(dam) do
    query =
      from(dp in Barragenspt.Hydrometrics.DataPoint,
        where:
          dp.param_name == "volume_last_day_month" and
            dp.site_id == ^dam.site_id and
            dp.colected_at >= ^query_limit(),
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
        basin: dam.name
      }
    end)
    |> Enum.sort(&(&1.timestamp < &2.timestamp))
    |> Enum.map(fn m -> Map.drop(m, [:timestamp]) end)
  end

  def current_level_for_dam(id) do
    query =
      from(dp in Barragenspt.Hydrometrics.DataPoint,
        where:
          dp.param_name == "volume_last_day_month" and
            dp.site_id == ^to_string(id),
        select: {
          fragment(
            "value / (SELECT (metadata  -> 'Albufeira' ->> 'Capacidade total (dam3)')::int from dam d where site_id = ?) * 100",
            ^id
          )
        },
        order_by: [desc: :colected_at],
        limit: 1
      )

    Barragenspt.Repo.one!(query)
  end

  def historical_level_for_dam(id) do
    query =
      from(dp in Barragenspt.Hydrometrics.DataPoint,
        where:
          dp.param_name == "volume_last_day_month" and
            fragment("extract(month from ?)", dp.colected_at) == ^Timex.now().month and
            dp.site_id == ^to_string(id),
        select: {
          fragment(
            "cast(avg(value) / (SELECT (metadata  -> 'Albufeira' ->> 'Capacidade total (dam3)')::int from dam d where site_id = ?) * 100 as int)",
            ^id
          )
        }
      )

    Barragenspt.Repo.one!(query)
  end

  defp parse_date(date) do
    {:ok, parsed_date} = Timex.parse(date, "{D}-{M}-{YYYY}")

    ts = Timex.to_unix(parsed_date)
    dt = Timex.format!(parsed_date, "{YYYY}-{M}-{D}")

    %{ts: ts, dt: dt}
  end

  defp build_map(basin, acc, dt, ts, value) do
    case Enum.find(acc, fn map -> map["date"] == dt end) do
      nil ->
        acc ++ [%{"ts" => ts, "#{basin}" => value, "date" => dt}]

      map ->
        new_map = Map.put(map, "#{basin}", value)

        Enum.reject(acc, fn map -> map["date"] == dt end) ++
          [new_map]
    end
  end

  defp query_limit do
    Timex.now()
    |> Timex.end_of_month()
    |> Timex.shift(months: -16)
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
