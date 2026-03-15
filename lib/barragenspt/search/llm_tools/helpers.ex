defmodule Barragenspt.Search.LLMTools.Helpers do
  @moduledoc false

  alias Barragenspt.Hydrometrics.{Dams, Basins}

  def resolve_dam_by_name(name) do
    case Dams.search(name, []) do
      [first | _] -> first.id
      [] -> nil
    end
  end

  def resolve_basin_by_name(name) do
    stats = Basins.summary_stats([])
    name_lower = String.downcase(name)
    case Enum.find(stats, fn s ->
           String.downcase(s.name || "") == name_lower or
             String.contains?(String.downcase(s.name || ""), name_lower)
         end) do
      nil -> nil
      s -> s.id
    end
  end

  def get_list(args, key) when is_map(args) do
    case args[key] do
      list when is_list(list) -> list
      _ -> nil
    end
  end

  def today_start_ms do
    DateTime.utc_now()
    |> DateTime.to_date()
    |> Date.to_iso8601()
    |> then(fn d -> NaiveDateTime.from_iso8601!("#{d}T00:00:00") end)
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix(:millisecond)
  end

  def to_float(%Decimal{} = d), do: Decimal.to_float(d)
  def to_float(n) when is_number(n), do: n * 1.0
  def to_float(_), do: nil

  def format_dam_search(%{id: id, name: name, basin_id: bid, current_storage: cs}) do
    %{
      dam_id: id,
      dam_name: name,
      basin_id: bid,
      current_storage_pct: to_float(cs)
    }
  end

  def format_dam_storage_item(%{site_id: id, site_name: name, basin_id: bid, basin_name: bname, current_storage: cs}) do
    %{
      dam_id: id,
      dam_name: name,
      basin_id: bid,
      basin_name: bname,
      current_storage_pct: (cs && to_float(cs)) || cs
    }
  end

  def format_dam_info(info) do
    %{
      dam_id: info.site_id,
      dam_name: info.site_name,
      basin_id: info.basin_id,
      basin_name: info.basin_name,
      current_storage_pct: to_float(info.current_storage_pct),
      current_storage_value: to_float(info.current_storage_value),
      total_capacity: info.total_capacity,
      colected_at: format_datetime(info.colected_at)
    }
  end

  def format_datetime(nil), do: nil
  def format_datetime(dt) when not is_nil(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")

  def format_basin_summary(%{id: id, name: name, observed_value: obs, historical_average: hist}) do
    %{
      basin_id: id,
      basin_name: name,
      observed_pct: to_float(obs),
      historical_average_pct: to_float(hist)
    }
  end

  def format_basin_dam(%{site_id: id, site_name: name, observed_value: obs, historical_average: hist, total_capacity: cap}) do
    %{
      dam_id: id,
      dam_name: name,
      observed_pct: to_float(obs),
      historical_average_pct: to_float(hist),
      total_capacity: cap
    }
  end
end
