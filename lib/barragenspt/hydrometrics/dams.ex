defmodule Barragenspt.Hydrometrics.Dams do
  import Ecto.Query
  use Nebulex.Caching

  alias Barragenspt.Geo.Coordinates

  alias Barragenspt.Models.Hydrometrics.{
    MonthlyAverageStorageBySite,
    DailyAverageStorageBySite,
    SiteCurrentStorage,
    DataPoint,
    DataPointWithDam,
    DataPointRealtime,
    Dam,
    DamUsage
  }

  alias Barragenspt.Repo
  alias Barragenspt.Cache
  alias Barragenspt.RealtimeDataPointsCache

  alias Flop.{Filter, Meta}

  @discharge_flow_params [
    "ouput_flow_rate_daily",
    "tributary_daily_flow",
    "effluent_daily_flow",
    "turbocharged_daily_flow"
  ]

  @decorate cacheable(
              cache: Cache,
              key: "adam_#{id}",
              ttl: :timer.hours(1)
            )
  def get(id) do
    Repo.one!(
      from(b in SiteCurrentStorage,
        join: d in Dam,
        on: b.site_id == d.site_id,
        where: b.site_id == ^id,
        select: %{
          basin_id: d.basin_id,
          basin_name: d.basin,
          site_id: b.site_id,
          site_name: d.name,
          current_storage_pct: fragment("round(?, 1)", b.current_storage_pct),
          current_storage_value: fragment("round(?, 1)", b.current_storage_value),
          colected_at: b.colected_at,
          metadata: d.metadata,
          total_capacity: d.total_capacity
        }
      )
    )
  end

  def all do
    Repo.all(from(b in Dam))
  end

  @decorate cacheable(
              cache: RealtimeDataPointsCache,
              key: "realtime_series_#{site_id}",
              ttl: :timer.hours(1)
            )
  def realtime_series(site_id) do
    from(d in DataPointRealtime,
      where: d.site_id == ^site_id,
      order_by: [asc: d.colected_at]
    )
    |> Repo.all()
    |> Enum.group_by(& &1.colected_at)
    |> Enum.sort_by(fn {t, _} -> t end)
    |> Enum.map(fn {t, rows_at_time} ->
      base = %{
        data: Calendar.strftime(t, "%d/%m %H:%M"),
        colected_at: t
      }

      Enum.reduce(rows_at_time, base, fn row, acc ->
        Map.put(acc, String.to_atom(row.param_name), decimal_to_float(row.value))
      end)
    end)
  end

  @decorate cacheable(
              cache: RealtimeDataPointsCache,
              key: "realtime_latest_#{site_id}_#{param_name}",
              ttl: :timer.minutes(15)
            )
  def realtime_latest_value(site_id, param_name)
      when is_binary(site_id) and is_binary(param_name) do
    from(d in DataPointRealtime,
      where: d.site_id == ^site_id and d.param_name == ^param_name,
      order_by: [desc: d.colected_at],
      limit: 1,
      select: d.value
    )
    |> Repo.one()
    |> decimal_to_float()
  end

  def latest_data_point_value(site_id, param_name)
      when is_binary(site_id) and is_binary(param_name) do
    from(dp in DataPoint,
      where: dp.site_id == ^site_id and dp.param_name == ^param_name,
      order_by: [desc: dp.colected_at],
      limit: 1,
      select: dp.value
    )
    |> Repo.one()
    |> decimal_to_float()
  end

  defp decimal_to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp decimal_to_float(n) when is_number(n), do: n * 1.0
  defp decimal_to_float(_), do: nil

  @decorate cacheable(
              cache: Cache,
              key: "usage_types",
              ttl: :timer.hours(1)
            )
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
        on: d.site_id == du.site_id,
        join: b in SiteCurrentStorage,
        on: d.site_id == b.site_id,
        where: ^filter,
        select: %{
          id: d.site_id,
          name: d.name,
          basin_id: d.basin_id,
          basin: d.basin,
          current_storage: b.current_storage_pct
        }
      )

    query
    |> distinct(true)
    |> Repo.all()
  end

  @doc """
  Name search for UI pickers (e.g. alert subject). Same filters as `search/2` but does **not**
  require a `SiteCurrentStorage` row, so dams still appear before matviews are populated.
  """
  def search_for_picker(name, usage_types \\ []) when is_binary(name) do
    name = String.trim(name)

    if name == "" do
      []
    else
      like = "%#{name}%"

      filter = dynamic([d, _du], ilike(d.name, ^like))

      filter =
        if usage_types != [] do
          dynamic([_d, du], ^filter and du.usage_name in ^usage_types)
        else
          filter
        end

      from(d in Dam,
        join: du in DamUsage,
        on: d.site_id == du.site_id,
        where: ^filter,
        select: %{
          id: d.site_id,
          name: d.name,
          basin_id: d.basin_id
        }
      )
      |> distinct(true)
      |> Repo.all()
    end
  end

  @decorate cacheable(
              cache: Cache,
              key: "river_names",
              ttl: :timer.hours(24)
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
              ttl: :timer.hours(1)
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
              ttl: :timer.hours(1)
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
              ttl: :timer.hours(1)
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
              ttl: :timer.hours(1)
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

  def discharge_stats(id, period \\ 2, unit)

  def discharge_stats(id, period, unit) do
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
        value: value |> Decimal.round(1) |> Decimal.to_float(),
        date: date
      }
    end)
    |> Enum.to_list()
  end

  def monthly_stats(id, period \\ 2)

  @decorate cacheable(cache: Cache, key: "for_site_#{id}-#{period}", ttl: :timer.hours(1))
  def monthly_stats(id, period) do
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
    # |> Stream.reject(fn %{observed_value: value} -> value > 100 end)
    # |> Stream.reject(fn %{historical_average: value} -> value > 100 end)
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

  def discharge_monthly_stats(id, period \\ 2)

  def discharge_monthly_stats(id, period) do
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

  @doc """
  Returns daily discharge flow series for all flow params (ouput_flow_rate_daily,
  tributary_daily_flow, effluent_daily_flow, turbocharged_daily_flow).
  `period_months` limits how many months back to fetch.
  Returns %{labels: ["d/m", ...], "param_name" => [values], ...}.
  """
  def discharge_flows_daily(site_id, period_months) do
    limit = query_limit(period_months, :month)

    rows =
      from(dp in DataPoint,
        where:
          dp.site_id == ^site_id and
            dp.param_name in ^@discharge_flow_params and
            dp.colected_at >= ^limit,
        group_by: [fragment("DATE(?)", dp.colected_at), dp.param_name],
        select: {fragment("DATE(?)", dp.colected_at), dp.param_name, sum(dp.value)}
      )
      |> Repo.all()

    build_flows_series(rows, "%d/%m")
  end

  @doc """
  Returns monthly aggregated discharge flow series. `period_years` limits years back.
  Returns %{labels: ["m/yyyy", ...], "param_name" => [values], ...}.
  """
  def discharge_flows_monthly(site_id, period_years) do
    limit = query_limit(period_years)

    rows =
      from(dp in DataPoint,
        where:
          dp.site_id == ^site_id and
            dp.param_name in ^@discharge_flow_params and
            dp.colected_at >= ^limit,
        group_by: [
          fragment(
            "DATE( date_trunc( 'month', ?) + interval '1 month' - interval '1 day')",
            dp.colected_at
          ),
          dp.param_name
        ],
        select: {
          fragment(
            "DATE( date_trunc( 'month', ?) + interval '1 month' - interval '1 day')",
            dp.colected_at
          ),
          dp.param_name,
          sum(dp.value)
        }
      )
      |> Repo.all()
      |> Enum.map(fn {date, param, sum_val} -> {date, param, sum_val} end)

    build_flows_series(rows, "%m/%Y")
  end

  defp build_flows_series(rows, date_format) do
    # Group by date -> %{param => value}
    by_date =
      Enum.reduce(rows, %{}, fn {date, param, value}, acc ->
        val_float = value |> Decimal.round(1) |> Decimal.to_float()
        Map.update(acc, date, %{param => val_float}, &Map.put(&1, param, val_float))
      end)

    dates = by_date |> Map.keys() |> Enum.sort(Date)
    labels = Enum.map(dates, &Calendar.strftime(&1, date_format))

    series =
      for param <- @discharge_flow_params do
        values = Enum.map(dates, &Map.get(Map.get(by_date, &1, %{}), param, 0))
        {param, values}
      end
      |> Map.new()

    Map.put(series, "labels", labels)
  end

  @decorate cacheable(
              cache: Cache,
              key: "dam_current_storage_for_sites_#{Enum.join(site_ids)}",
              ttl: :timer.hours(1)
            )
  def current_storage_for_sites(site_ids) when is_list(site_ids) do
    Repo.all(
      from(b in SiteCurrentStorage,
        where: b.site_id in ^site_ids,
        select: %{
          site_id: b.site_id,
          current_storage: fragment("round(?, 1)", b.current_storage_pct)
        }
      )
    )
  end

  @decorate cacheable(cache: Cache, key: "dam_current_storage_#{site_id}", ttl: :timer.hours(1))
  def current_storage(site_id) when is_binary(site_id) do
    Repo.one(
      from(b in SiteCurrentStorage,
        where: b.site_id == ^site_id,
        select: %{
          current_storage: fragment("round(?, 1)", b.current_storage_pct)
        }
      )
    )
  end

  @decorate cacheable(
              cache: Cache,
              key: "dams_current_storage_#{Enum.join(usage_types, "-")}",
              ttl: :timer.hours(1)
            )
  def current_storage(usage_types) when is_list(usage_types) do
    current_storage_filtered(usage_types)
  end

  @decorate cacheable(
              cache: Cache,
              key: "hourly_stats_for_site_#{id}-#{period}",
              ttl: :timer.hours(1)
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
    # |> Stream.reject(fn %{value: value} -> value > 100 end)
    |> Enum.to_list()
    |> Enum.sort(&(Timex.compare(&1.date, &2.date) < 0))
  end

  @decorate cacheable(cache: Cache, key: "last_elevation#{site_id}", ttl: :timer.hours(1))
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

  @decorate cacheable(cache: Cache, key: "dam_last_data_point_#{site_id}", ttl: :timer.hours(1))
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
        select: %{
          basin_id: d.basin_id,
          basin_name: d.basin,
          site_id: b.site_id,
          site_name: d.name,
          current_storage: fragment("round(?, 1)", b.current_storage_pct),
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
        where: du.usage_name in ^usage_types,
        select: %{
          basin_id: d.basin_id,
          basin_name: d.basin,
          site_id: b.site_id,
          site_name: d.name,
          current_storage: fragment("round(?, 1)", b.current_storage_pct),
          colected_at: b.colected_at,
          metadata: d.metadata
        }
      )
    )
  end

  @data_points_flop_opts [for: DataPointWithDam, repo: Repo, replace_invalid_params: true]

  # Export ignores UI page size; opts `max_limit` overrides schema (100) for this call only.
  @data_points_csv_export_max 50_000

  @data_points_chart_max_points 2_000

  @data_points_csv_export_flop_opts [
    for: DataPointWithDam,
    repo: Repo,
    replace_invalid_params: true,
    max_limit: @data_points_csv_export_max
  ]

  # Total-row count for Flop pagination is expensive on large tables. Cache it
  # per filter set (not per page/order) with a short TTL; stale totals are acceptable
  # briefly while new data_points are ingested.
  @data_points_count_cache_ttl :timer.minutes(2)

  @doc """
  Distinct dam names from `dam`, ordered alphabetically (for dashboard filter dropdowns).

  Pass a basin name to restrict names to that basin; pass `nil` or `""` (via default)
  for all basins.
  """
  @spec list_data_points_filter_dam_names(String.t() | nil) :: [String.t()]
  def list_data_points_filter_dam_names(basin \\ nil)

  def list_data_points_filter_dam_names(basin) when basin in [nil, ""] do
    from(d in Dam,
      where: not is_nil(d.name) and d.name != "",
      distinct: [asc: d.name],
      order_by: [asc: d.name],
      select: d.name
    )
    |> Repo.all()
  end

  def list_data_points_filter_dam_names(basin) when is_binary(basin) do
    from(d in Dam,
      where: not is_nil(d.name) and d.name != "",
      where: d.basin == ^basin,
      distinct: [asc: d.name],
      order_by: [asc: d.name],
      select: d.name
    )
    |> Repo.all()
  end

  @doc """
  Distinct basin names from `dam`, ordered alphabetically (for dashboard filter dropdowns).
  """
  @spec list_data_points_filter_basins() :: [String.t()]
  def list_data_points_filter_basins do
    from(d in Dam,
      where: not is_nil(d.basin) and d.basin != "",
      distinct: [asc: d.basin],
      order_by: [asc: d.basin],
      select: d.basin
    )
    |> Repo.all()
  end

  @doc """
  Returns true if validated Flop params include a non-empty `param_name` filter.

  The data-points dashboard only loads rows when this is true.
  """
  @spec data_points_param_name_filter_set?(Flop.t()) :: boolean()
  def data_points_param_name_filter_set?(%Flop{filters: filters}) do
    Enum.any?(filters || [], &param_name_filter_has_value?/1)
  end

  defp param_name_filter_has_value?(%Filter{field: field, value: value})
       when field in [:param_name, "param_name"] do
    nonempty_filter_value?(value)
  end

  defp param_name_filter_has_value?(%{field: field, value: value})
       when field in [:param_name, "param_name"] do
    nonempty_filter_value?(value)
  end

  defp param_name_filter_has_value?(_), do: false

  defp nonempty_filter_value?(v) when is_binary(v), do: v != ""

  defp nonempty_filter_value?(v) when is_list(v) do
    Enum.any?(v, fn
      s when is_binary(s) -> s != ""
      _ -> false
    end)
  end

  defp nonempty_filter_value?(v) when not is_nil(v), do: true
  defp nonempty_filter_value?(_), do: false

  @doc """
  Lists rows from the `data_points_with_dam` view (`dam` ⋈ `data_points` on `site_id`)
  with Flop filtering, sorting and pagination.

  Rows are returned only when a `param_name` filter with a value is present; otherwise
  the result list is empty and no query is run against the view.

  The **total row count** used for pagination metadata is cached in `Barragenspt.Cache`
  for #{div(@data_points_count_cache_ttl, 60_000)} minutes per distinct filter set
  (same filters → same count; page and sort do not affect the cached value).
  """
  @spec list_data_points(map()) ::
          {:ok, {[DataPointWithDam.t()], Meta.t()}} | {:error, Meta.t()}
  def list_data_points(params \\ %{}) when is_map(params) do
    params = normalize_data_points_query_params(params)

    case Flop.validate(params, @data_points_flop_opts) do
      {:ok, flop} ->
        if data_points_param_name_filter_set?(flop) do
          count = cached_data_points_total_count(flop)

          {:ok,
           Flop.run(DataPointWithDam, flop, Keyword.put(@data_points_flop_opts, :count, count))}
        else
          meta =
            Flop.meta(
              DataPointWithDam,
              flop,
              Keyword.put(@data_points_flop_opts, :count, 0)
            )

          {:ok, {[], meta}}
        end

      {:error, %Meta{} = meta} ->
        {:error, meta}
    end
  end

  @doc """
  Returns up to #{@data_points_csv_export_max} rows from `data_points_with_dam` using the
  same Flop filters and ordering as `list_data_points/1`, but always from page 1 with a
  large page size (pagination params in `params` are replaced for the export).
  """
  @spec list_data_points_for_csv_export(map()) ::
          {:ok, [DataPointWithDam.t()]}
          | {:error, Meta.t()}
          | {:error, :missing_param_name_filter}
  def list_data_points_for_csv_export(params) when is_map(params) do
    params = normalize_data_points_query_params(params)

    export_params =
      params
      |> Map.drop([
        "page",
        "page_size",
        "offset",
        "limit",
        :page,
        :page_size,
        :offset,
        :limit
      ])
      |> Map.put("page", 1)
      |> Map.put("page_size", @data_points_csv_export_max)

    case Flop.validate(export_params, @data_points_csv_export_flop_opts) do
      {:ok, flop} ->
        if data_points_param_name_filter_set?(flop) do
          rows = Flop.all(DataPointWithDam, flop, @data_points_csv_export_flop_opts)
          {:ok, rows}
        else
          {:error, :missing_param_name_filter}
        end

      {:error, %Meta{} = meta} ->
        {:error, meta}
    end
  end

  @doc """
  Aggregates `data_points_with_dam` rows by a Postgres `date_trunc` bucket and `dam_name`,
  using the same Flop filters as `list_data_points/1` (no table pagination).

  Returns `avg(value)` per `(bucket, dam_name)`. Use `data_points_chart_series_for_ui/2` to
  pick a default grain and optionally coarsen when the series exceeds a cap.
  """
  @spec data_points_chart_series(map(), :hour | :day | :week | :month) ::
          {:ok, [map()]}
          | {:error, Meta.t()}
          | {:error, :missing_param_name_filter}
  def data_points_chart_series(params, grain) when grain in [:hour, :day, :week, :month] do
    params = normalize_data_points_query_params(params)
    chart_params = prepare_data_points_chart_flop_params(params)

    case Flop.validate(chart_params, @data_points_flop_opts) do
      {:ok, flop} ->
        if data_points_param_name_filter_set?(flop) do
          rows = data_points_chart_aggregated_rows(flop, grain)
          {:ok, rows}
        else
          {:error, :missing_param_name_filter}
        end

      {:error, %Meta{} = meta} ->
        {:error, meta}
    end
  end

  @doc """
  Like `data_points_chart_series/2`, but chooses `preferred_grain` or a heuristic from date
  filters, then coarsens (`hour` → `day` → `week` → `month`) until row count is ≤
  #{@data_points_chart_max_points} (or `:month` is reached).

  Each row map has string keys for JSON: `"bucket"`, `"dam_name"`, `"avg_value"` (float).
  """
  @spec data_points_chart_series_for_ui(map(), :hour | :day | :week | :month | nil) ::
          {:ok, [map()], map()}
          | {:error, Meta.t()}
          | {:error, :missing_param_name_filter}
  def data_points_chart_series_for_ui(params, preferred_grain \\ nil) do
    params = normalize_data_points_query_params(params)
    chart_params = prepare_data_points_chart_flop_params(params)

    case Flop.validate(chart_params, @data_points_flop_opts) do
      {:ok, flop} ->
        if data_points_param_name_filter_set?(flop) do
          start_grain = preferred_grain || default_chart_grain_from_flop(flop)
          start_grain = normalize_chart_grain(start_grain)
          chain = chart_grain_escalation_chain(start_grain)

          result =
            Enum.reduce_while(chain, nil, fn grain, _ ->
              rows = data_points_chart_aggregated_rows(flop, grain)

              cond do
                rows == [] ->
                  {:halt, {:empty, grain}}

                length(rows) <= @data_points_chart_max_points ->
                  {:halt, {:ok, rows, grain, grain != start_grain, false}}

                grain == :month ->
                  {:halt, {:ok, rows, grain, grain != start_grain, true}}

                true ->
                  {:cont, nil}
              end
            end)

          case result do
            {:empty, grain} ->
              json_rows = []
              meta = chart_response_meta(grain, start_grain, false, false)
              {:ok, json_rows, meta}

            {:ok, rows, used_grain, escalated, over_cap} ->
              json_rows = Enum.map(rows, &chart_row_to_json_map/1)

              meta =
                chart_response_meta(used_grain, start_grain, escalated, over_cap)

              {:ok, json_rows, meta}
          end
        else
          {:error, :missing_param_name_filter}
        end

      {:error, %Meta{} = meta} ->
        {:error, meta}
    end
  end

  @doc """
  Heuristic default chart bucket from `colected_at` filter span (fallback: last 60 days).
  """
  @spec default_chart_grain_from_flop(Flop.t()) :: :hour | :day | :week | :month
  def default_chart_grain_from_flop(%Flop{} = flop) do
    {from_ndt, to_ndt} = colected_at_range_from_flop_filters(flop.filters || [])
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    {from_ndt, to_ndt} =
      case {from_ndt, to_ndt} do
        {nil, nil} -> {NaiveDateTime.add(now, -60, :day), now}
        {nil, t} -> {NaiveDateTime.add(t, -60, :day), t}
        {f, nil} -> {f, now}
        {f, t} -> {f, t}
      end

    seconds = NaiveDateTime.diff(to_ndt, from_ndt, :second)

    cond do
      seconds <= 48 * 3600 -> :hour
      seconds <= 60 * 86400 -> :day
      seconds <= 550 * 86400 -> :week
      true -> :month
    end
  end

  defp chart_response_meta(used_grain, start_grain, escalated, over_cap) do
    %{
      grain: used_grain,
      grain_label: chart_grain_label_pt(used_grain),
      grain_auto_adjusted: escalated,
      over_point_cap: over_cap,
      start_grain: start_grain
    }
  end

  defp chart_grain_label_pt(:hour), do: "hora"
  defp chart_grain_label_pt(:day), do: "dia"
  defp chart_grain_label_pt(:week), do: "semana"
  defp chart_grain_label_pt(:month), do: "mês"

  defp normalize_chart_grain(g) when g in [:hour, :day, :week, :month], do: g
  defp normalize_chart_grain(_), do: :day

  defp chart_grain_escalation_chain(:hour), do: [:hour, :day, :week, :month]
  defp chart_grain_escalation_chain(:day), do: [:day, :week, :month]
  defp chart_grain_escalation_chain(:week), do: [:week, :month]
  defp chart_grain_escalation_chain(:month), do: [:month]

  defp prepare_data_points_chart_flop_params(params) do
    params
    |> Map.drop([
      "page",
      "page_size",
      "offset",
      "limit",
      :page,
      :page_size,
      :offset,
      :limit
    ])
    |> Map.put("page", 1)
    |> Map.put("page_size", 1)
  end

  defp chart_grain_to_pg_string(:hour), do: "hour"
  defp chart_grain_to_pg_string(:day), do: "day"
  defp chart_grain_to_pg_string(:week), do: "week"
  defp chart_grain_to_pg_string(:month), do: "month"

  defp data_points_chart_aggregated_rows(%Flop{} = flop, grain) do
    pg = chart_grain_to_pg_string(grain)
    base = from(d in DataPointWithDam, as: :data_point_with_dam)
    filtered = Flop.filter(base, flop, @data_points_flop_opts)

    # Two-step aggregation: PostgreSQL rejects GROUP BY when SELECT uses
    # date_trunc($1, ...) and GROUP BY date_trunc($3, ...) — different params
    # are not considered the same expression. Here the outer query groups by
    # bucket/dam_name columns projected once in the inner query.
    bucketed =
      from(d in subquery(filtered),
        select: %{
          bucket: fragment("date_trunc(?, ?)", ^pg, d.colected_at),
          dam_name: d.dam_name,
          param_name: d.param_name,
          value: d.value
        }
      )

    from(r in subquery(bucketed),
      group_by: [r.bucket, r.dam_name, r.param_name],
      order_by: [asc: r.bucket, asc: r.dam_name, asc: r.param_name],
      select: %{
        bucket: r.bucket,
        dam_name: r.dam_name,
        param_name: r.param_name,
        avg_value: avg(r.value)
      }
    )
    |> Repo.all()
  end

  defp chart_row_to_json_map(%{bucket: bucket, dam_name: dam_name, param_name: param_name, avg_value: avg}) do
    %{
      "bucket" => naive_bucket_to_iso(bucket),
      "dam_name" => dam_name,
      "param_name" => param_name,
      "avg_value" => decimal_avg_to_float(avg)
    }
  end

  defp naive_bucket_to_iso(%NaiveDateTime{} = ndt),
    do: NaiveDateTime.to_iso8601(ndt)

  defp naive_bucket_to_iso(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  defp naive_bucket_to_iso(_), do: nil

  defp decimal_avg_to_float(nil), do: nil
  defp decimal_avg_to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp decimal_avg_to_float(n) when is_number(n), do: n * 1.0

  defp colected_at_range_from_flop_filters(filters) when is_list(filters) do
    lower =
      filters
      |> Enum.find_value(fn f -> colected_at_bound_value(f, [:>=, :>, ">=", ">"]) end)

    upper =
      filters
      |> Enum.find_value(fn f -> colected_at_bound_value(f, [:<=, :<, "<=", "<"]) end)

    {parse_filter_naive_datetime(lower), parse_filter_naive_datetime(upper)}
  end

  defp colected_at_bound_value(%Filter{field: field, op: op, value: v}, ops) do
    if colected_at_field?(field) and op in ops, do: v, else: nil
  end

  defp colected_at_bound_value(%{"field" => field, "op" => op, "value" => v}, ops) do
    atom_op = op_to_atom(op)
    if colected_at_field?(field) and atom_op in ops, do: v, else: nil
  end

  defp colected_at_bound_value(%{field: field, op: op, value: v}, ops) do
    atom_op = op_to_atom(op)
    if colected_at_field?(field) and atom_op in ops, do: v, else: nil
  end

  defp colected_at_bound_value(_, _), do: nil

  defp colected_at_field?(field),
    do: field in [:colected_at, "colected_at"]

  defp op_to_atom(op) when is_atom(op), do: op

  defp op_to_atom(op) when is_binary(op) do
    case op do
      "==" -> :==
      ">=" -> :>=
      "<=" -> :<=
      ">" -> :>
      "<" -> :<
      other ->
        try do
          String.to_existing_atom(other)
        rescue
          ArgumentError -> op
        end
    end
  end

  defp parse_filter_naive_datetime(nil), do: nil

  defp parse_filter_naive_datetime(%NaiveDateTime{} = ndt), do: ndt

  defp parse_filter_naive_datetime(s) when is_binary(s) do
    case NaiveDateTime.from_iso8601(s) do
      {:ok, dt} -> dt
      _ -> parse_filter_naive_datetime_from_date_only(s)
    end
  end

  defp parse_filter_naive_datetime_from_date_only(<<_::binary-size(10)>> = date_only) do
    case Date.from_iso8601(date_only) do
      {:ok, %Date{} = date} -> NaiveDateTime.new!(date, ~T[00:00:00])
      _ -> nil
    end
  end

  defp parse_filter_naive_datetime_from_date_only(_), do: nil

  defp cached_data_points_total_count(%Flop{} = flop) do
    key = data_points_count_cache_key(flop)

    case Cache.get(key) do
      nil ->
        count = Flop.count(DataPointWithDam, flop, @data_points_flop_opts)
        :ok = Cache.put(key, count, ttl: @data_points_count_cache_ttl)
        count

      count when is_integer(count) ->
        count
    end
  end

  # Remove optional dam/basin filters when the dropdown is left blank so Flop does not
  # build `field == ""` (or stale ilike) conditions.
  defp normalize_data_points_query_params(params) when is_map(params) do
    case params do
      %{"filters" => filters} when is_map(filters) ->
        normalized =
          filters
          |> drop_blank_geo_filters()
          |> reindex_filters()
          |> expand_colected_at_date_filters()

        Map.put(params, "filters", normalized)

      %{filters: filters} when is_map(filters) ->
        normalized =
          filters
          |> drop_blank_geo_filters()
          |> reindex_filters()
          |> expand_colected_at_date_filters()

        Map.put(params, :filters, normalized)

      _ ->
        params
    end
  end

  # UI uses type="date" (YYYY-MM-DD). Expand to naive datetimes so Flop/Ecto filtering
  # matches the full calendar days in the DB.
  defp expand_colected_at_date_filters(filters) when is_map(filters) do
    Map.new(filters, fn {k, f} -> {k, maybe_expand_colected_at_date_filter(f)} end)
  end

  defp maybe_expand_colected_at_date_filter(%{} = f) do
    field = Map.get(f, "field") || Map.get(f, :field)
    op = Map.get(f, "op") || Map.get(f, :op)
    value = Map.get(f, "value") || Map.get(f, :value)

    if colected_at_filter_field?(field) and is_binary(value) and date_only_string?(value) do
      expanded = expand_colected_at_day_boundary(value, op)
      put_filter_map_value(f, expanded)
    else
      f
    end
  end

  defp colected_at_filter_field?(:colected_at), do: true
  defp colected_at_filter_field?("colected_at"), do: true
  defp colected_at_filter_field?(_), do: false

  defp date_only_string?(value) do
    Regex.match?(~r/^\d{4}-\d{2}-\d{2}$/, value)
  end

  defp expand_colected_at_day_boundary(date, op) do
    case normalize_filter_op(op) do
      x when x in [:>, :>=] -> "#{date} 00:00:00"
      x when x in [:<, :<=] -> "#{date} 23:59:59"
      _ -> "#{date} 00:00:00"
    end
  end

  defp normalize_filter_op(op) when op in [:>, :>=, :<, :<=], do: op
  defp normalize_filter_op(">"), do: :>
  defp normalize_filter_op(">="), do: :>=
  defp normalize_filter_op("<"), do: :<
  defp normalize_filter_op("<="), do: :<=
  defp normalize_filter_op(_), do: :>=

  defp put_filter_map_value(%{} = f, new_value) do
    cond do
      Map.has_key?(f, "value") -> Map.put(f, "value", new_value)
      Map.has_key?(f, :value) -> Map.put(f, :value, new_value)
      true -> Map.put(f, "value", new_value)
    end
  end

  defp drop_blank_geo_filters(filters) when is_map(filters) do
    filters
    |> Enum.reject(fn {_idx, f} -> blank_geo_filter?(f) end)
    |> Map.new()
  end

  defp blank_geo_filter?(f) when is_map(f) do
    field =
      case Map.get(f, "field") || Map.get(f, :field) do
        f when is_atom(f) -> Atom.to_string(f)
        f when is_binary(f) -> f
        _ -> nil
      end

    value = Map.get(f, "value") || Map.get(f, :value)

    field in ["dam_name", "basin", "param_name"] and geo_filter_value_blank?(value)
  end

  defp blank_geo_filter?(_), do: false

  defp geo_filter_value_blank?(v) when v in [nil, ""], do: true
  defp geo_filter_value_blank?(v) when is_list(v), do: v == []
  defp geo_filter_value_blank?(_), do: false

  defp reindex_filters(filters) when is_map(filters) and map_size(filters) == 0, do: filters

  defp reindex_filters(filters) when is_map(filters) do
    filters
    |> Enum.sort_by(fn {k, _} -> filter_slot_index(k) end)
    |> Enum.map(fn {_k, v} -> v end)
    |> Enum.with_index()
    |> Map.new(fn {v, i} -> {Integer.to_string(i), v} end)
  end

  defp filter_slot_index(k) when is_integer(k), do: k

  defp filter_slot_index(k) do
    k |> to_string() |> String.to_integer()
  end

  defp data_points_count_cache_key(%Flop{filters: filters}) do
    normalized =
      (filters || [])
      |> Enum.map(&filter_triple_for_cache/1)
      |> Enum.sort()

    digest = :crypto.hash(:sha256, :erlang.term_to_binary(normalized))
    {:data_points_with_dam_flop_count, digest}
  end

  defp filter_triple_for_cache(%Filter{field: field, op: op, value: value}),
    do: {field, op, value}

  defp filter_triple_for_cache(%{} = map) do
    field = Map.get(map, :field) || Map.get(map, "field")
    op = Map.get(map, :op) || Map.get(map, "op")
    value = Map.get(map, :value) || Map.get(map, "value")
    {field, op, value}
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
