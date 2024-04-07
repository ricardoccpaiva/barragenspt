defmodule Barragenspt.Meteo.Precipitation do
  import Ecto.Query
  use Nebulex.Caching
  alias Barragenspt.Repo
  alias Barragenspt.MeteoDataCache, as: Cache

  alias Barragenspt.Models.Meteo.{
    LegendMapping,
    PrecipitationDailyValue,
    PrecipitationMonthlyValue
  }

  @ttl :timer.hours(24)

  @decorate cacheable(
              cache: Cache,
              key: "reference_monthly",
              ttl: @ttl
            )
  def get_reference_monthly() do
    sub_query =
      from p in PrecipitationDailyValue,
        join: l in LegendMapping,
        on: p.color_hex == l.color_hex,
        where:
          fragment("EXTRACT(year FROM ?) <= ?", p.date, 2020) and
            l.meteo_index == "precipitation" and l.variant == "daily",
        group_by: fragment("EXTRACT(day FROM ?), EXTRACT(month FROM ?)", p.date, p.date),
        order_by: fragment("EXTRACT(day FROM ?), EXTRACT(month FROM ?)", p.date, p.date),
        select: %{
          day: fragment("CAST(EXTRACT(day FROM ?) AS integer)", p.date),
          month: fragment("CAST(EXTRACT(month FROM ?) AS integer)", p.date),
          value: fragment("(avg(?) + avg(?)) / 2", l.max_value, l.min_value)
        }

    query =
      from(c in subquery(sub_query),
        join: l in LegendMapping,
        where:
          c.value >= l.min_value and c.value <= l.max_value and l.variant == "daily" and
            l.meteo_index == "precipitation",
        group_by: [c.month, l.color_hex],
        select: %{
          color_hex: l.color_hex,
          month: c.month,
          value: sum(c.value)
        }
      )

    Repo.all(query)
  end

  @decorate cacheable(
              cache: Cache,
              key: "monthly_#{year}",
              ttl: @ttl
            )
  def get_monthly(year) do
    sub_query =
      from p in PrecipitationMonthlyValue,
        join: l in LegendMapping,
        on: p.color_hex == l.color_hex,
        where: p.year == ^year and l.meteo_index == "precipitation" and l.variant == "monthly",
        group_by: [p.month, p.year],
        order_by: p.month,
        select: %{
          year: p.year,
          month: p.month,
          value: avg(fragment("(?) + (?)", l.max_value, l.min_value)) / 2
        }

    query =
      from(c in subquery(sub_query),
        join: l in LegendMapping,
        where:
          c.value >= l.min_value and c.value <= l.max_value and l.variant == "monthly" and
            l.meteo_index == "precipitation",
        group_by: [c.year, c.month, l.color_hex],
        select: %{
          color_hex: l.color_hex,
          year: c.year,
          month: c.month,
          value: sum(c.value)
        }
      )

    Repo.all(query)
  end

  @decorate cacheable(
              cache: Cache,
              key: "get_#{year}",
              ttl: @ttl
            )
  def get(year) do
    sub_query =
      from p in PrecipitationDailyValue,
        join: l in LegendMapping,
        on: p.color_hex == l.color_hex,
        where:
          fragment("EXTRACT(year FROM ?) = ?", p.date, ^year) and
            l.meteo_index == "precipitation" and l.variant == "daily",
        group_by: p.date,
        order_by: p.date,
        select: %{
          date: p.date,
          value: fragment("(avg(?) + avg(?)) / 2", l.max_value, l.min_value)
        }

    query =
      from(c in subquery(sub_query),
        join: l in LegendMapping,
        where:
          c.value >= l.min_value and c.value <= l.max_value and l.variant == "daily" and
            l.meteo_index == "precipitation",
        group_by: [c.date, l.color_hex],
        select: %{
          color_hex: l.color_hex,
          date: c.date,
          value: avg(c.value)
        }
      )

    Repo.all(query)
  end

  @decorate cacheable(
              cache: Cache,
              key: "bounded_#{start_date}_#{end_date}",
              ttl: @ttl
            )
  def get_bounded(start_date, end_date) do
    sub_query =
      from p in PrecipitationDailyValue,
        join: l in LegendMapping,
        on: p.color_hex == l.color_hex,
        where:
          p.date >= ^start_date and p.date <= ^end_date and
            l.meteo_index == "precipitation" and l.variant == "daily",
        group_by: p.date,
        order_by: p.date,
        select: %{
          date: p.date,
          value: fragment("(avg(?) + avg(?)) / 2", l.max_value, l.min_value)
        }

    query =
      from(c in subquery(sub_query),
        join: l in LegendMapping,
        where:
          c.value >= l.min_value and c.value <= l.max_value and l.variant == "daily" and
            l.meteo_index == "precipitation",
        group_by: [c.date, l.color_hex],
        select: %{
          color_hex: l.color_hex,
          date: c.date,
          value: avg(c.value)
        }
      )

    Repo.all(query)
  end

  @decorate cacheable(
              cache: Cache,
              key: "get_#{year}_#{month}",
              ttl: @ttl
            )
  def get(year, month) do
    sub_query =
      from p in PrecipitationDailyValue,
        join: l in LegendMapping,
        on: p.color_hex == l.color_hex,
        where:
          fragment("EXTRACT(year FROM ?) = ?", p.date, ^year) and
            fragment("EXTRACT(month FROM ?) = ?", p.date, ^month) and
            l.meteo_index == "precipitation" and l.variant == "daily",
        group_by: p.date,
        order_by: p.date,
        select: %{
          date: p.date,
          value: fragment("(avg(?) + avg(?)) / 2", l.max_value, l.min_value)
        }

    query =
      from(c in subquery(sub_query),
        join: l in LegendMapping,
        where:
          c.value >= l.min_value and c.value <= l.max_value and l.variant == "daily" and
            l.meteo_index == "precipitation",
        group_by: [c.date, l.color_hex],
        select: %{
          color_hex: l.color_hex,
          date: c.date,
          value: avg(c.value)
        }
      )

    Repo.all(query)
  end
end
