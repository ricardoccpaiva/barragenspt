defmodule Barragenspt.Hydrometrics.Stats do
  import Ecto.Query
  alias Barragenspt.Hydrometrics.Basins

  def for_basin(%{id: id, basin: basin}) do
    query =
      from(dp in Barragenspt.Hydrometrics.DataPoint,
        where:
          dp.param_name == "volume_last_day_month" and
            dp.basin_id == ^to_string(id) and
            dp.colected_at >= ^query_limit(),
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
      rounded_value = value |> Decimal.round(2) |> Decimal.to_float()
      %{ts: ts, dt: dt} = parse_date(date)

      %{value: rounded_value, timestamp: ts, date: dt}
    end)
    |> Enum.reduce([], fn %{value: value, timestamp: ts, date: dt}, acc ->
      build_map(basin, acc, dt, ts, value)
    end)
    |> Enum.sort(&(Map.get(&1, "ts") < Map.get(&2, "ts")))
    |> Enum.map(fn m -> Map.drop(m, ["ts"]) end)
  end

  def for_basins() do
    all_basins = Basins.all()

    query =
      from(dp in Barragenspt.Hydrometrics.DataPoint,
        where:
          dp.param_name == "volume_last_day_month" and
            dp.colected_at >= ^query_limit_all_basins(),
        group_by: [
          :basin_id,
          fragment("extract(month from ?)", dp.colected_at),
          fragment("extract(year from ?)", dp.colected_at)
        ],
        select: {
          dp.basin_id,
          fragment(
            "(sum(value) / (SELECT sum((metadata  -> 'Albufeira' ->> 'Capacidade total (dam3)')::int) from dam d where basin_id = cast(? as int))) * 100",
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
    |> Enum.map(fn {basin_id, value, date} ->
      rounded_value = value |> Decimal.round(2) |> Decimal.to_float()

      %{ts: ts, dt: dt} = parse_date(date)

      %{basin_id: basin_id, value: rounded_value, timestamp: ts, date: dt}
    end)
    |> Enum.reduce([], fn %{basin_id: basin_id, value: value, timestamp: ts, date: dt}, acc ->
      {bid, ""} = Integer.parse(basin_id)
      %{basin: basin} = Enum.find(all_basins, fn b -> b[:id] == bid end)

      build_map(basin, acc, dt, ts, value)
    end)
    |> Enum.sort(&(Map.get(&1, "ts") < Map.get(&2, "ts")))
    |> Enum.map(fn m -> Map.drop(m, ["ts"]) end)
  end

  def current_level_for_dam(id) do
    query =
      from(dp in Barragenspt.Hydrometrics.DataPoint,
        where:
          dp.param_name == "volume_last_day_month" and
            dp.site_id == ^to_string(id),
        select: {
          fragment(
            "cast(value / (SELECT (metadata  -> 'Albufeira' ->> 'Capacidade total (dam3)')::int from dam d where site_id = ?) * 100 as int)",
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
