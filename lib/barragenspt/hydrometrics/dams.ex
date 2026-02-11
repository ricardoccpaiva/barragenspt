defmodule Barragenspt.Hydrometrics.Dams do
  import Ecto.Query
  use Nebulex.Caching

  alias Barragenspt.Geo.Coordinates

  alias Barragenspt.Models.Hydrometrics.{
    MonthlyAverageStorageBySite,
    DailyAverageStorageBySite,
    SiteCurrentStorage,
    DataPoint,
    Dam,
    DamUsage
  }

  alias Barragenspt.Repo
  alias Barragenspt.Cache

  @ttl :timer.hours(1)

  @decorate cacheable(
              cache: Cache,
              key: "adam_#{id}",
              ttl: @ttl
            )
  def get(id) do
    Repo.one!(
      from(b in SiteCurrentStorage,
        join: d in Dam,
        on: b.site_id == d.site_id,
        where: b.current_storage <= 100 and b.site_id == ^id,
        select: %{
          basin_id: d.basin_id,
          basin_name: d.basin,
          site_id: b.site_id,
          site_name: d.name,
          current_storage: fragment("round(?, 1)", b.current_storage),
          colected_at: b.colected_at,
          metadata: d.metadata
        }
      )
    )
  end

  def all do
    Repo.all(from(b in Dam))
  end

  def usage_types do
    from(b in DamUsage,
      select: {b.usage_name}
    )
    |> distinct(true)
    |> Repo.all()
  end

  def usage_types(site_id) do
    from(b in DamUsage,
      where: b.site_id == ^site_id,
      select: b.usage_name
    )
    |> distinct(true)
    |> Repo.all()
  end

  def search(name, usage_types) do
    like = "%#{name}%"

    filter = dynamic([d, _du], ilike(d.name, ^like))

    filter =
      if usage_types != [] do
        dynamic([_d, du], ^filter and du.usage_name in ^usage_types)
      else
        filter
      end

    query =
      from(d in Dam,
        join: du in DamUsage,
        join: b in SiteCurrentStorage,
        on: d.site_id == b.site_id,
        on: d.site_id == du.site_id,
        where: ^filter,
        select: %{id: d.site_id, name: d.name, basin_id: d.basin_id, current_storage: b.current_storage}
      )

    query
    |> distinct(true)
    |> Repo.all()
  end

  @decorate cacheable(
              cache: Cache,
              key: "river_names",
              ttl: @ttl
            )
  def get_river_names() do
    all()
    |> Enum.filter(fn d -> d.river != nil end)
    |> Enum.map(fn d ->
      %{
        basin_id: d.basin_id,
        site_id: d.site_id,
        river_display_name: d.metadata |> Map.get("Barragem") |> Map.get("Curso de água"),
        river_name: d.river
      }
    end)
    |> Enum.uniq_by(fn %{river_display_name: rdn} -> rdn end)
    |> Enum.sort_by(&Map.fetch(&1, :river_name))
  end

  @decorate cacheable(
              cache: Cache,
              key: "dams_by_river#{river_name}",
              ttl: @ttl
            )
  def get_dams_by_river(river_name) do
    all()
    |> Enum.filter(fn d -> d.river != nil end)
    |> Enum.map(fn d ->
      %{
        basin_id: d.basin_id,
        site_id: d.site_id,
        river_display_name: d.metadata |> Map.get("Barragem") |> Map.get("Curso de água"),
        river_name: d.river
      }
    end)
    |> Enum.filter(fn r -> r.river_name == river_name end)
    |> Enum.map(fn r -> %{basin_id: r.basin_id, site_id: r.site_id} end)
  end

  @decorate cacheable(
              cache: Cache,
              key: "bounding_box-#{Enum.join(site_ids, "-")}",
              ttl: @ttl
            )
  def bounding_box(site_ids) when is_list(site_ids) do
    query = from(d in Dam, where: d.site_id in ^site_ids)

    query
    |> Barragenspt.Repo.all()
    |> Stream.map(fn dam -> Coordinates.from_dam(dam) end)
    |> Stream.map(fn %{lat: lat, lon: lon} -> [lon, lat] end)
    |> Enum.to_list()
    |> Geocalc.bounding_box_for_points()
  end

  @decorate cacheable(
              cache: Cache,
              key: "bounding_box-#{basin_id}",
              ttl: @ttl
            )
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

    discharge_stats = discharge_stats(id, period, :month)

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
          sum(dp.value) / sum(d.total_capacity),
          fragment("DATE(?)", dp.colected_at)
        }
      )

    query
    |> Repo.all()
    |> Stream.map(fn {value, date} ->
      build_daily_stats_map(value, date, historic_values, discharge_stats)
    end)
    |> Enum.to_list()
    |> Enum.sort(&(Timex.compare(&1.date, &2.date) < 0))
  end

  defp build_daily_stats_map(value, date, historic_values, discharge_stats) do
    %{
      date: date,
      observed_value: value |> Decimal.mult(100) |> Decimal.round(1) |> Decimal.to_float(),
      historical_average:
        historic_values
        |> Enum.find(fn h -> h.period == "#{date.day}-#{date.month}" end)
        |> Map.get(:value)
        |> Decimal.round(2)
        |> Decimal.to_float(),
      discharge_value:
        case Enum.find(discharge_stats, &(&1.date == date)) do
          %{value: value} -> value
          _ -> 0
        end
    }
  end

  defp discharge_stats(id, period \\ 2, unit) do
    query =
      from(dp in DataPoint,
        join: d in Dam,
        on: d.site_id == dp.site_id,
        where:
          dp.param_name == "ouput_flow_rate_daily" and
            dp.site_id == ^id and
            dp.colected_at >= ^query_limit(period, unit),
        select: {
          dp.value,
          fragment("DATE(?)", dp.colected_at)
        }
      )

    query
    |> Repo.all()
    |> Stream.map(fn {value, date} ->
      %{
        value: value |> Decimal.mult(100) |> Decimal.round(1) |> Decimal.to_float(),
        date: date
      }
    end)
    |> Enum.to_list()
  end

  @decorate cacheable(cache: Cache, key: "for_site_#{id}-#{period}", ttl: @ttl)
  def monthly_stats(id, period \\ 2) do
    historic_values =
      Repo.all(
        from(b in MonthlyAverageStorageBySite,
          where: b.site_id == ^id
        )
      )

    discharge_stats = discharge_monthly_stats(id, period)

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
      build_monthly_stats_map(value, date, historic_values, discharge_stats)
    end)
    |> Stream.reject(fn %{observed_value: value} -> value > 100 end)
    |> Stream.reject(fn %{historical_average: value} -> value > 100 end)
    |> Enum.to_list()
    |> Enum.sort(&(Timex.compare(&1.date, &2.date) < 0))
  end

  defp build_monthly_stats_map(value, date, historic_values, discharge_stats) do
    %{
      observed_value: value |> Decimal.mult(100) |> Decimal.round(1) |> Decimal.to_float(),
      date: date,
      historical_average:
        historic_values
        |> Enum.find(fn h -> h.period == date.month end)
        |> Map.get(:value)
        |> Decimal.round(2)
        |> Decimal.to_float(),
      discharge_value:
        case Enum.find(discharge_stats, &(&1.date == date)) do
          %{value: value} -> value
          _ -> 0
        end
    }
  end

  defp discharge_monthly_stats(id, period \\ 2) do
    query =
      from(dp in DataPoint,
        join: d in Dam,
        on: d.site_id == dp.site_id,
        where:
          dp.param_name == "ouput_flow_rate_daily" and
            dp.site_id == ^id and
            dp.colected_at >= ^query_limit(period),
        group_by: [
          fragment(
            "DATE( date_trunc( 'month', ?) + interval '1 month' - interval '1 day')",
            dp.colected_at
          )
        ],
        select: {
          sum(dp.value),
          fragment(
            "DATE( date_trunc( 'month', ?) + interval '1 month' - interval '1 day')",
            dp.colected_at
          )
        }
      )

    query
    |> Repo.all()
    |> Stream.map(fn {value, date} -> build_discharge_monthly_stats_map(value, date) end)
    |> Enum.to_list()
  end

  defp build_discharge_monthly_stats_map(value, date) do
    %{
      value: value |> Decimal.mult(100) |> Decimal.round(1) |> Decimal.to_float(),
      date: date
    }
  end

  @decorate cacheable(
              cache: Cache,
              key: "dam_current_storage_for_sites_#{Enum.join(site_ids)}",
              ttl: @ttl
            )
  def current_storage_for_sites(site_ids) when is_list(site_ids) do
    Repo.all(
      from(b in SiteCurrentStorage,
        where: b.site_id in ^site_ids and b.current_storage <= 100,
        select: %{
          site_id: b.site_id,
          current_storage: fragment("round(?, 1)", b.current_storage)
        }
      )
    )
  end

  @decorate cacheable(cache: Cache, key: "dam_current_storage_#{site_id}", ttl: @ttl)
  def current_storage(site_id) when is_binary(site_id) do
    Repo.one(
      from(b in SiteCurrentStorage,
        where: b.site_id == ^site_id and b.current_storage <= 100,
        select: %{
          current_storage: fragment("round(?, 1)", b.current_storage)
        }
      )
    )
  end

  @decorate cacheable(
              cache: Cache,
              key: "dams_current_storage_#{Enum.join(usage_types, "-")}",
              ttl: @ttl
            )
  def current_storage(usage_types) when is_list(usage_types) do
    current_storage_filtered(usage_types)
  end

  @decorate cacheable(
              cache: Cache,
              key: "hourly_stats_for_site_#{id}-#{period}",
              ttl: @ttl
            )
  def hourly_stats(id, period \\ 1) do
    %{last_data_point: ldp} = last_data_point(id)

    query =
      from(dp in DataPoint,
        join: d in Dam,
        on: d.site_id == dp.site_id,
        where:
          dp.param_name == "volume_last_hour" and
            dp.site_id == ^id and
            dp.colected_at >= ^query_limit(ldp, period, :week),
        group_by: [
          :site_id,
          :colected_at
        ],
        select: {
          sum(dp.value) / sum(d.total_capacity),
          dp.colected_at
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
    |> Enum.to_list()
    |> Enum.sort(&(Timex.compare(&1.date, &2.date) < 0))
  end

  @decorate cacheable(cache: Cache, key: "last_elevation#{site_id}", ttl: @ttl)
  def last_elevation(site_id) do
    Repo.one(
      from(dp in DataPoint,
        where: dp.site_id == ^site_id and dp.param_name == "elevation_last_hour",
        order_by: [desc: dp.colected_at],
        limit: 1,
        select: %{
          value: dp.value,
          colected_at: dp.colected_at
        }
      )
    )
  end

  @decorate cacheable(cache: Cache, key: "dam_last_data_point_#{site_id}", ttl: @ttl)
  def last_data_point(site_id) do
    Repo.one(
      from(dp in DataPoint,
        where: dp.site_id == ^site_id and dp.param_name == "volume_last_hour",
        order_by: [desc: dp.colected_at],
        limit: 1,
        select: %{
          last_data_point: dp.colected_at
        }
      )
    )
  end

  def daily_average_storage_by_site_query(basin_id, usage_types) do
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
        q.site_id
      ],
      order_by: [q.period, q.site_id],
      select: %{
        period: q.period,
        site_id: q.site_id,
        value: avg(q.average) * 100
      }
  end

  def sites_current_storage_query(basin_id, usage_types) do
    filter = dynamic([dp, _du], dp.param_name == "volume_last_hour")

    filter =
      if basin_id do
        dynamic([dp, _du], ^filter and dp.basin_id == ^basin_id)
      else
        filter
      end

    filter =
      if usage_types != [] do
        dynamic([_dp, du], ^filter and du.usage_name in ^usage_types)
      else
        filter
      end

    subquery =
      from(dp in DataPoint,
        join: du in DamUsage,
        on: dp.site_id == du.site_id,
        where: ^filter,
        select: %{
          site_id: dp.site_id,
          basin_id: dp.basin_id,
          value: dp.value,
          colected_at: dp.colected_at,
          rn:
            fragment(
              "row_number() OVER (PARTITION BY ? ORDER BY ? DESC)",
              dp.site_id,
              dp.colected_at
            )
        }
      )

    from(dp in subquery(subquery),
      join: d in Dam,
      on: dp.site_id == d.site_id,
      where: dp.rn == 1,
      select: %{
        site_id: dp.site_id,
        basin_id: dp.basin_id,
        value: dp.value,
        colected_at: dp.colected_at
      }
    )
  end

  defp current_storage_filtered([]) do
    Repo.all(
      from(b in SiteCurrentStorage,
        join: d in Dam,
        on: b.site_id == d.site_id,
        where: b.current_storage <= 100,
        select: %{
          basin_id: d.basin_id,
          basin_name: d.basin,
          site_id: b.site_id,
          site_name: d.name,
          current_storage: fragment("round(?, 1)", b.current_storage),
          colected_at: b.colected_at,
          metadata: d.metadata
        }
      )
    )
  end

  defp current_storage_filtered(usage_types) do
    Repo.all(
      from(b in SiteCurrentStorage,
        join: du in DamUsage,
        on: b.site_id == du.site_id,
        join: d in Dam,
        on: b.site_id == d.site_id,
        where:
          b.current_storage <= 100 and
            du.usage_name in ^usage_types,
        select: %{
          basin_id: d.basin_id,
          basin_name: d.basin,
          site_id: b.site_id,
          site_name: d.name,
          current_storage: fragment("round(?, 1)", b.current_storage),
          colected_at: b.colected_at,
          metadata: d.metadata
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

  defp query_limit(period, :week) do
    Timex.now()
    |> Timex.end_of_month()
    |> Timex.shift(weeks: period * -1)
    |> Timex.beginning_of_month()
    |> Timex.to_naive_datetime()
  end

  defp query_limit(date, period, :week) do
    date
    |> Timex.shift(weeks: period * -1)
    |> Timex.to_naive_datetime()
  end
end
