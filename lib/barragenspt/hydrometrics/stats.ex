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
