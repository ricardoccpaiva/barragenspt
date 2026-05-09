defmodule Barragenspt.Hydrometrics.StorageReport do
  @moduledoc """
  Builds a visual storage report from persisted hydrometric data.

  This module is intentionally separate from `BasinReport`, which is used for AI
  prompt/fact generation.
  """

  import Ecto.Query

  alias Barragenspt.Geo.Coordinates
  alias Barragenspt.Models.Hydrometrics.{Dam, DataPoint}
  alias Barragenspt.Repo

  @report_timezone "Europe/Lisbon"
  @volume_param "volume_last_hour"
  @volume_param_id "354895398"
  @weekly_reading_lookback_days 5

  def build(opts \\ []) do
    basin = opts |> Keyword.get(:basin) |> normalize_basin()
    reference_at = Keyword.get(opts, :reference_at) || current_week_monday_reference_at()

    dams =
      basin
      |> current_dam_rows(reference_at)
      |> Enum.map(&enrich_dam/1)

    basins =
      dams
      |> Enum.group_by(& &1.basin)
      |> Enum.map(fn {basin_name, basin_dams} -> build_basin(basin_name, basin_dams) end)
      |> Enum.sort_by(& &1.name)

    %{
      generated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      report_date: reference_at,
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

  defp current_dam_rows(basin, reference_at) do
    start_at = Timex.shift(reference_at, days: -@weekly_reading_lookback_days)

    storage_points =
      from dp in DataPoint,
        where:
          dp.param_name == @volume_param and dp.param_id == @volume_param_id and
            dp.colected_at >= ^start_at and
            dp.colected_at <= ^reference_at,
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
      from p in subquery(storage_points),
        where: p.rn == 1,
        select: %{site_id: p.site_id, value: p.value, colected_at: p.colected_at}

    query =
      from d in Dam,
        as: :dam,
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
          current_storage_pct: nil,
          current_storage_value: p.value,
          colected_at: p.colected_at,
          reference_at: type(^reference_at, :naive_datetime)
        }

    query =
      if is_nil(basin) do
        query
      else
        from [d, _s] in query, where: d.basin == ^basin
      end

    Repo.all(query)
  end

  defp normalize_basin(nil), do: nil
  defp normalize_basin(""), do: nil
  defp normalize_basin("__all__"), do: nil
  defp normalize_basin(value) when is_binary(value), do: String.trim(value)
  defp normalize_basin(_), do: nil

  defp current_week_monday_reference_at do
    today =
      @report_timezone
      |> Timex.now()
      |> Timex.to_date()

    monday = Date.add(today, 1 - Date.day_of_week(today))

    NaiveDateTime.new!(monday, ~T[23:00:00])
  end

  defp enrich_dam(row) do
    capacity = number(row.total_capacity)
    current_value = number(row.current_storage_value)
    current_pct = number(row.current_storage_pct) || pct(current_value, capacity)
    current_volume = current_volume(row.current_storage_value, current_pct, capacity)
    reference_at = row.colected_at || row.reference_at
    previous_pct = historical_pct(row.site_id, reference_at, capacity, :previous_week)
    reference_pct = historical_pct(row.site_id, reference_at, capacity, :reference_average)

    %{
      site_id: row.site_id,
      basin_id: row.basin_id,
      basin: row.basin,
      name: row.name,
      river: row.river,
      total_capacity: capacity,
      current_pct: round_or_nil(current_pct),
      current_volume: round_or_nil(current_volume),
      previous_week_pct: round_or_nil(previous_pct),
      reference_avg_pct: round_or_nil(reference_pct),
      week_delta: delta(current_pct, previous_pct),
      reference_delta: delta(current_pct, reference_pct),
      colected_at: row.colected_at,
      coordinates: coordinates(row),
      status: status(current_pct)
    }
  end

  defp build_basin(name, dams) do
    sorted_dams = Enum.sort_by(dams, &sort_name(&1.name))
    capacity = sum(dams, :total_capacity)
    current_volume = sum(dams, :current_volume)
    previous_volume = weighted_volume(dams, :previous_week_pct)
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
      previous_week_pct: round_or_nil(previous_pct),
      reference_avg_pct: round_or_nil(reference_pct),
      week_delta: delta(current_pct, previous_pct),
      reference_delta: delta(current_pct, reference_pct),
      status: status(current_pct),
      centroid: centroid(dams),
      dams: sorted_dams
    }
  end

  defp build_summary(basins) do
    capacity = sum(basins, :total_capacity)
    current_volume = sum(basins, :current_volume)
    previous_volume = weighted_volume(basins, :previous_week_pct)
    reference_volume = weighted_volume(basins, :reference_avg_pct)
    current_pct = pct(current_volume, capacity)
    previous_pct = pct(previous_volume, capacity)
    reference_pct = pct(reference_volume, capacity)

    %{
      total_capacity: round_or_nil(capacity),
      current_volume: round_or_nil(current_volume),
      current_pct: round_or_nil(current_pct),
      previous_week_pct: round_or_nil(previous_pct),
      reference_avg_pct: round_or_nil(reference_pct),
      week_delta: delta(current_pct, previous_pct),
      reference_delta: delta(current_pct, reference_pct),
      attention_count: Enum.count(basins, &(&1.status in [:alert, :low]))
    }
  end

  defp historical_pct(_site_id, _at, capacity, _mode)
       when not is_number(capacity) or capacity <= 0,
       do: nil

  defp historical_pct(_site_id, nil, _capacity, _mode), do: nil

  defp historical_pct(site_id, at, capacity, :previous_week) do
    target_at = Timex.shift(at, days: -7)
    start_at = Timex.shift(target_at, days: -@weekly_reading_lookback_days)

    value =
      Repo.one(
        from dp in DataPoint,
          where:
            dp.site_id == ^site_id and dp.param_name == @volume_param and
              dp.param_id == @volume_param_id and dp.colected_at >= ^start_at and
              dp.colected_at <= ^target_at,
          order_by: [desc: dp.colected_at],
          limit: 1,
          select: dp.value
      )

    value |> number() |> pct(capacity)
  end

  defp historical_pct(site_id, at, capacity, :reference_average) do
    date = NaiveDateTime.to_date(at)
    {iso_year, iso_week} = :calendar.iso_week_number(Date.to_erl(date))

    value =
      Repo.one(
        from dp in DataPoint,
          where:
            dp.site_id == ^site_id and dp.param_name == @volume_param and
              dp.param_id == @volume_param_id and
              fragment("extract(week from ?)::int", dp.colected_at) == ^iso_week and
              fragment("extract(isoyear from ?)::int", dp.colected_at) < ^iso_year,
          select: avg(dp.value)
      )

    value |> number() |> pct(capacity)
  end

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

  defp current_volume(value, _current_pct, _capacity) when not is_nil(value), do: number(value)
  defp current_volume(_value, current_pct, capacity), do: weighted_value(current_pct, capacity)

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

  defp sort_name(nil), do: ""

  defp sort_name(value) do
    value
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/\b(d[aeo]s?|d')\b/u, "")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  defp present?(value), do: is_binary(value) and String.trim(value) != ""
end
