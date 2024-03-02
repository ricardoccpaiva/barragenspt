defmodule Barragenspt.Meteo.Precipitation do
  import Ecto.Query
  use Nebulex.Caching
  alias Barragenspt.Cache
  alias Barragenspt.Repo
  alias Barragenspt.Hydrometrics.SvgArea
  alias Barragenspt.Hydrometrics.{PrecipitationDailyValue, PrecipitationMonthlyValue}
  alias Barragenspt.Hydrometrics.LegendMapping

  @decorate cacheable(
              cache: Cache,
              key: "precipitation_data_by_scale_#{year}_#{month}_absolute",
              ttl: 99_999_999
            )
  def get_precipitation_data_by_scale(year, month, :absolute) do
    query =
      from pdv in PrecipitationDailyValue,
        join: sa in SvgArea,
        on: pdv.svg_path_hash == sa.svg_path_hash,
        join: plm in LegendMapping,
        on:
          pdv.color_hex == plm.color_hex and
            pdv.geographic_area_type == sa.geographic_area_type and
            sa.geographic_area_type ==
              ^"municipality",
        where:
          plm.meteo_index == "precipitation" and
            fragment("EXTRACT(year FROM ?) = ?", pdv.date, ^year) and
            fragment("EXTRACT(month FROM ?) = ?", pdv.date, ^month),
        group_by: [pdv.date, pdv.color_hex],
        order_by: [asc: pdv.date],
        select: %{
          value: sum((plm.max_value + plm.min_value) / 2),
          date: pdv.date,
          color_hex: pdv.color_hex
        }

    Repo.all(query)
  end

  @decorate cacheable(
              cache: Cache,
              key: "precipitation_data_by_scale_#{year}_#{month}_relative",
              ttl: 99_999_999
            )
  def get_precipitation_data_by_scale(year, month, :relative) do
    query =
      from pdv in PrecipitationDailyValue,
        join: sa in SvgArea,
        on: pdv.svg_path_hash == sa.svg_path_hash,
        where:
          pdv.geographic_area_type == ^"municipality" and
            fragment("EXTRACT(year FROM ?) = ?", pdv.date, ^year) and
            fragment("EXTRACT(month FROM ?) = ?", pdv.date, ^month),
        group_by: [pdv.date, pdv.color_hex],
        order_by: [asc: pdv.date],
        select: %{
          count: count(1),
          date: pdv.date,
          color_hex: pdv.color_hex,
          value: sum(sa.area) / 60541.204940844229249 * 100
        }

    Repo.all(query)
  end

  @decorate cacheable(
              cache: Cache,
              key: "precipitation_data_by_scale_#{year}_absolute",
              ttl: 99_999_999
            )
  def get_precipitation_data_by_scale(year, :absolute) do
    query =
      from pdv in PrecipitationMonthlyValue,
        join: sa in SvgArea,
        on: pdv.svg_path_hash == sa.svg_path_hash,
        join: plm in LegendMapping,
        on:
          pdv.color_hex == plm.color_hex and
            pdv.geographic_area_type == sa.geographic_area_type and
            sa.geographic_area_type ==
              ^"municipality",
        where: plm.meteo_index == "precipitation" and pdv.year == ^year,
        group_by: [pdv.year, pdv.month, pdv.color_hex],
        order_by: [asc: pdv.year, asc: pdv.month],
        select: %{
          value: sum((plm.max_value + plm.min_value) / 2),
          year: pdv.year,
          month: pdv.month,
          color_hex: pdv.color_hex
        }

    Repo.all(query)
  end

  @decorate cacheable(
              cache: Cache,
              key: "precipitation_data_by_scale_#{year}_relative",
              ttl: 99_999_999
            )
  def get_precipitation_data_by_scale(year, :relative) do
    query =
      from pdv in PrecipitationMonthlyValue,
        join: sa in SvgArea,
        on: pdv.svg_path_hash == sa.svg_path_hash,
        where:
          pdv.year == ^year and
            sa.geographic_area_type == ^"municipality",
        group_by: [pdv.year, pdv.month, pdv.color_hex],
        order_by: [asc: pdv.year, asc: pdv.month],
        select: %{
          count: count(1),
          year: pdv.year,
          month: pdv.month,
          color_hex: pdv.color_hex,
          value: sum(sa.area) / 60541.204940844229249 * 100
        }

    Repo.all(query)
  end

  @decorate cacheable(
              cache: Cache,
              key: "precipitation_data_by_scale_#{year}_#{month}",
              ttl: 99_999_999
            )
  def get_precipitation_data_by_scale(year, month) do
    query =
      from pdv in PrecipitationDailyValue,
        join: sa in SvgArea,
        on: pdv.svg_path_hash == sa.svg_path_hash,
        join: plm in LegendMapping,
        on:
          pdv.color_hex == plm.color_hex and
            pdv.geographic_area_type == sa.geographic_area_type,
        where:
          plm.meteo_index == "precipitation" and
            fragment("EXTRACT(year FROM ?) = ?", pdv.date, ^year) and
            fragment("EXTRACT(month FROM ?) = ?", pdv.date, ^month),
        group_by: [pdv.date, pdv.color_hex],
        order_by: [asc: pdv.date, asc: pdv.date],
        select: %{
          count: count(1),
          date: pdv.date,
          color_hex: pdv.color_hex,
          weight: sum(sa.area) / 60541.204940844229249
        }

    Repo.all(query)
  end

  @decorate cacheable(
              cache: Cache,
              key: "precipitation_data_#{year}",
              ttl: 99_999_999
            )
  def get_precipitation_data(year) do
    subquery =
      from pdv in PrecipitationDailyValue,
        join: sa in SvgArea,
        on: pdv.svg_path_hash == sa.svg_path_hash,
        join: plm in LegendMapping,
        on: pdv.color_hex == plm.color_hex,
        where: plm.meteo_index == "precipitation",
        group_by: [pdv.date, pdv.color_hex, plm.max_value],
        order_by: [asc: pdv.date],
        select: %{
          count: count(1),
          date: pdv.date,
          color_hex: pdv.color_hex,
          mean_value: plm.max_value,
          weight: sum(sa.area) / 60541.204940844229249
        }

    query =
      from(c in subquery(subquery),
        group_by: c.date,
        where: fragment("EXTRACT(year FROM ?) = ?", c.date, ^year),
        select: %{
          date: c.date,
          weighted_average: sum(c.mean_value * c.weight) / sum(c.weight)
        }
      )

    Repo.all(query)
  end
end
