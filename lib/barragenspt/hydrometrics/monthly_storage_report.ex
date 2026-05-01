defmodule Barragenspt.Hydrometrics.MonthlyStorageReport do
  @moduledoc """
  Builds a monthly storage report using the last available value of each closed month.
  """

  import Ecto.Query

  alias Barragenspt.Geo.Coordinates
  alias Barragenspt.Models.Hydrometrics.{Dam, DataPoint}
  alias Barragenspt.Repo

  @volume_param "volume_last_day_month"

  def build(opts \\ []) do
    basin = opts |> Keyword.get(:basin) |> normalize_basin()
    today = Keyword.get(opts, :today, Date.utc_today())
    bounds = selectable_month_bounds(today: today)

    requested_month =
      opts
      |> Keyword.get(:report_month)
      |> normalize_month_param()

    report_month = resolve_report_month(requested_month, bounds)

    current_rows = current_dam_rows_for_month(basin, report_month)
    previous_values = previous_month_values_by_site(basin, report_month)
    reference_values = reference_month_values_by_site(basin, report_month)

    dams =
      Enum.map(current_rows, fn row ->
        enrich_dam(row, previous_values, reference_values)
      end)

    basins =
      dams
      |> Enum.group_by(& &1.basin)
      |> Enum.map(fn {basin_name, basin_dams} -> build_basin(basin_name, basin_dams) end)
      |> Enum.sort_by(& &1.name)

    %{
      generated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      report_month: report_month,
      selected_basin: basin,
      basin_count: length(basins),
      dam_count: length(dams),
      summary: build_summary(basins),
      basins: basins
    }
  end

  def list_basins do
    Repo.all(
      from d in Dam,
        where: not is_nil(d.basin) and d.basin != "",
        distinct: true,
        order_by: [asc: d.basin],
        select: d.basin
    )
  end

  def selectable_month_bounds(opts \\ []) do
    today = Keyword.get(opts, :today, Date.utc_today())
    latest_closed = latest_closed_month(today)

    earliest =
      Repo.one(
        from dp in DataPoint,
          where: dp.param_name == @volume_param,
          select: min(dp.colected_at)
      )
      |> case do
        %NaiveDateTime{} = dt ->
          Date.new!(dt.year, dt.month, 1)

        nil ->
          latest_closed
      end

    %{min: earliest, max: latest_closed}
  end

  def latest_closed_month(today \\ Date.utc_today()) do
    today
    |> Date.beginning_of_month()
    |> Date.add(-1)
    |> Date.beginning_of_month()
  end

  defp resolve_report_month(nil, %{max: max}), do: max

  defp resolve_report_month(report_month, %{min: min, max: max}) do
    cond do
      Date.compare(report_month, min) == :lt -> min
      Date.compare(report_month, max) == :gt -> max
      true -> report_month
    end
  end

  defp normalize_month_param(%Date{} = date), do: Date.beginning_of_month(date)
  defp normalize_month_param(_), do: nil

  defp current_dam_rows_for_month(basin, report_month) do
    {start_at, end_at} = month_bounds(report_month)

    month_points =
      from dp in DataPoint,
        where:
          dp.param_name == @volume_param and dp.colected_at >= ^start_at and
            dp.colected_at < ^end_at,
        select: %{
          site_id: dp.site_id,
          value: dp.value,
          colected_at: dp.colected_at,
          rn:
            over(
              row_number(),
              :site_window
            )
        },
        windows: [site_window: [partition_by: dp.site_id, order_by: [desc: dp.colected_at]]]

    latest_points =
      from p in subquery(month_points),
        where: p.rn == 1,
        select: %{site_id: p.site_id, value: p.value, colected_at: p.colected_at}

    query =
      from d in Dam,
        join: p in subquery(latest_points),
        on: p.site_id == d.site_id,
        where: not is_nil(d.basin) and d.basin != "",
        order_by: [asc: d.basin, asc: d.name],
        select: %{
          site_id: d.site_id,
          basin_id: d.basin_id,
          basin: d.basin,
          name: d.name,
          river: d.river,
          metadata: d.metadata,
          total_capacity: d.total_capacity,
          current_storage_value: p.value,
          colected_at: p.colected_at
        }

    query =
      if is_nil(basin) do
        query
      else
        from [d, _p] in query, where: d.basin == ^basin
      end

    Repo.all(query)
  end

  defp previous_month_values_by_site(basin, report_month) do
    previous_month = report_month |> Timex.shift(months: -1) |> Date.beginning_of_month()
    values_by_site_for_month(basin, previous_month)
  end

  defp values_by_site_for_month(basin, report_month) do
    {start_at, end_at} = month_bounds(report_month)

    month_points =
      from dp in DataPoint,
        where:
          dp.param_name == @volume_param and dp.colected_at >= ^start_at and
            dp.colected_at < ^end_at,
        select: %{
          site_id: dp.site_id,
          value: dp.value,
          rn:
            over(
              row_number(),
              :site_window
            )
        },
        windows: [site_window: [partition_by: dp.site_id, order_by: [desc: dp.colected_at]]]

    query =
      from p in subquery(month_points),
        join: d in Dam,
        on: d.site_id == p.site_id,
        where: p.rn == 1,
        select: {p.site_id, p.value}

    query =
      if is_nil(basin) do
        query
      else
        from [p, d] in query, where: d.basin == ^basin
      end

    query
    |> Repo.all()
    |> Map.new(fn {site_id, value} -> {site_id, number(value)} end)
  end

  defp reference_month_values_by_site(basin, report_month) do
    month = report_month.month
    year = report_month.year

    query =
      from dp in DataPoint,
        join: d in Dam,
        on: d.site_id == dp.site_id,
        where:
          dp.param_name == @volume_param and
            fragment("extract(month from ?)::int", dp.colected_at) == ^month and
            fragment("extract(year from ?)::int", dp.colected_at) < ^year,
        group_by: dp.site_id,
        select: {dp.site_id, avg(dp.value)}

    query =
      if is_nil(basin) do
        query
      else
        from [dp, d] in query, where: d.basin == ^basin
      end

    query
    |> Repo.all()
    |> Map.new(fn {site_id, value} -> {site_id, number(value)} end)
  end

  defp enrich_dam(row, previous_values, reference_values) do
    capacity = number(row.total_capacity)
    current_value = number(row.current_storage_value)
    current_pct = pct(current_value, capacity)
    previous_pct = previous_values |> Map.get(row.site_id) |> pct(capacity)
    reference_pct = reference_values |> Map.get(row.site_id) |> pct(capacity)

    %{
      site_id: row.site_id,
      basin_id: row.basin_id,
      basin: row.basin,
      name: row.name,
      river: row.river,
      total_capacity: capacity,
      current_pct: round_or_nil(current_pct),
      current_volume: round_or_nil(current_value),
      previous_month_pct: round_or_nil(previous_pct),
      reference_avg_pct: round_or_nil(reference_pct),
      month_delta: delta(current_pct, previous_pct),
      reference_delta: delta(current_pct, reference_pct),
      colected_at: row.colected_at,
      coordinates: coordinates(row),
      status: status(current_pct)
    }
  end

  defp build_basin(name, dams) do
    capacity = sum(dams, :total_capacity)
    current_volume = sum(dams, :current_volume)
    previous_volume = weighted_volume(dams, :previous_month_pct)
    reference_volume = weighted_volume(dams, :reference_avg_pct)
    current_pct = pct(current_volume, capacity)
    previous_pct = pct(previous_volume, capacity)
    reference_pct = pct(reference_volume, capacity)

    %{
      name: name,
      basin_id: dams |> Enum.map(& &1.basin_id) |> Enum.find(&present?/1),
      dam_count: length(dams),
      total_capacity: round_or_nil(capacity),
      current_pct: round_or_nil(current_pct),
      current_volume: round_or_nil(current_volume),
      previous_month_pct: round_or_nil(previous_pct),
      reference_avg_pct: round_or_nil(reference_pct),
      month_delta: delta(current_pct, previous_pct),
      reference_delta: delta(current_pct, reference_pct),
      status: status(current_pct),
      centroid: centroid(dams),
      dams: dams
    }
  end

  defp build_summary(basins) do
    capacity = sum(basins, :total_capacity)
    current_volume = sum(basins, :current_volume)
    previous_volume = weighted_volume(basins, :previous_month_pct)
    reference_volume = weighted_volume(basins, :reference_avg_pct)
    current_pct = pct(current_volume, capacity)
    previous_pct = pct(previous_volume, capacity)
    reference_pct = pct(reference_volume, capacity)

    %{
      total_capacity: round_or_nil(capacity),
      current_volume: round_or_nil(current_volume),
      current_pct: round_or_nil(current_pct),
      previous_month_pct: round_or_nil(previous_pct),
      reference_avg_pct: round_or_nil(reference_pct),
      month_delta: delta(current_pct, previous_pct),
      reference_delta: delta(current_pct, reference_pct),
      attention_count: Enum.count(basins, &(&1.status in [:alert, :low]))
    }
  end

  defp month_bounds(%Date{} = report_month) do
    start_at = NaiveDateTime.new!(Date.beginning_of_month(report_month), ~T[00:00:00])

    end_at =
      report_month
      |> Date.beginning_of_month()
      |> Timex.shift(months: 1)
      |> NaiveDateTime.new!(~T[00:00:00])

    {start_at, end_at}
  end

  defp normalize_basin(nil), do: nil
  defp normalize_basin(""), do: nil
  defp normalize_basin("__all__"), do: nil
  defp normalize_basin(value) when is_binary(value), do: String.trim(value)
  defp normalize_basin(_), do: nil

  defp coordinates(%{metadata: metadata} = dam) when is_map(metadata) do
    try do
      Coordinates.from_dam(dam)
    rescue
      _ -> nil
    end
  end

  defp coordinates(_), do: nil

  defp centroid(items) do
    coords =
      items
      |> Enum.map(& &1.coordinates)
      |> Enum.reject(&is_nil/1)

    if coords == [] do
      nil
    else
      %{
        lat: Enum.sum(Enum.map(coords, & &1.lat)) / length(coords),
        lon: Enum.sum(Enum.map(coords, & &1.lon)) / length(coords)
      }
    end
  end

  defp weighted_volume(items, pct_key) do
    values =
      Enum.map(items, fn item -> weighted_value(Map.get(item, pct_key), item.total_capacity) end)
      |> Enum.reject(&is_nil/1)

    if values == [], do: nil, else: Enum.sum(values)
  end

  defp weighted_value(pct, capacity) when is_number(pct) and is_number(capacity),
    do: pct * capacity / 100

  defp weighted_value(_pct, _capacity), do: nil

  defp sum(items, key) do
    values =
      items
      |> Enum.map(&Map.get(&1, key))
      |> Enum.reject(&is_nil/1)

    if values == [], do: nil, else: Enum.sum(values)
  end

  defp pct(nil, _capacity), do: nil
  defp pct(_value, nil), do: nil
  defp pct(_value, capacity) when capacity <= 0, do: nil
  defp pct(value, capacity), do: value / capacity * 100

  defp delta(current, previous) when is_number(current) and is_number(previous),
    do: Float.round(current - previous, 1)

  defp delta(_current, _previous), do: nil

  defp status(nil), do: :unknown
  defp status(pct) when pct < 30, do: :alert
  defp status(pct) when pct < 50, do: :low
  defp status(pct) when pct < 70, do: :normal
  defp status(_pct), do: :good

  defp number(%Decimal{} = value), do: Decimal.to_float(value)
  defp number(value) when is_integer(value), do: value * 1.0
  defp number(value) when is_float(value), do: value
  defp number(_value), do: nil

  defp round_or_nil(nil), do: nil
  defp round_or_nil(value) when is_number(value), do: Float.round(value, 1)

  defp present?(value), do: is_binary(value) and String.trim(value) != ""
end
