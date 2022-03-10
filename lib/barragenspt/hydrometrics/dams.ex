defmodule Barragenspt.Hydrometrics.Dams do
  import Ecto.Query
  use Nebulex.Caching

  alias Barragenspt.Geo.Coordinates

  alias Barragenspt.Hydrometrics.{
    MonthlyAverageStorageBySite,
    DataPoint,
    Dam
  }

  alias Barragenspt.Repo
  alias Barragenspt.Cache

  @ttl :timer.hours(24)

  def bounding_box(basin_id) do
    query = from d in Dam, where: d.basin_id == ^basin_id

    query
    |> Barragenspt.Repo.all()
    |> Enum.map(fn dam -> Coordinates.from_dam(dam) end)
    |> Enum.map(fn %{lat: lat, lon: lon} -> [lon, lat] end)
    |> Geocalc.bounding_box_for_points()
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
      hdata = build_average_data(historic_values, :site_id, dam.site_id, m.date)

      [m, hdata]
    end)
    |> Enum.to_list()
    |> List.flatten()
    |> Enum.sort(&(Timex.compare(&1.date, &2.date) < 0))
    |> Enum.map(fn %{date: date} = m ->
      Map.replace!(m, :date, Timex.format!(date, "{YYYY}-{M}-{D}"))
    end)
  end

  defp build_average_data(historic_values, field, id, date) do
    hval =
      Enum.find(historic_values, fn h ->
        Map.get(h, field) == id and h.period == date.month
      end)

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
end
