defmodule Barragenspt.Search.LLMTools.Basins do
  @moduledoc false

  alias Barragenspt.Hydrometrics.Basins
  alias Barragenspt.Search.LLMTools.Helpers

  def exec("get_basin_storage", args), do: exec_get_basin_storage(args)
  def exec("list_basins", args), do: exec_list_basins(args)
  def exec("get_basin_dams", args), do: exec_get_basin_dams(args)
  def exec("get_basin_storage_evolution", args), do: exec_get_basin_storage_evolution(args)
  def exec(_, _), do: nil

  def exec_get_basin_storage(args) do
    basin_id = args["basin_id"]
    basin_name = args["basin_name"]

    id =
      cond do
        is_binary(basin_id) and basin_id != "" -> basin_id
        is_binary(basin_name) and basin_name != "" -> Helpers.resolve_basin_by_name(basin_name)
        true -> nil
      end

    if id do
      try do
        all_basins = Basins.summary_stats([])
        basin_row = Enum.find(all_basins, fn s -> s.id == id end)
        dam_stats = Basins.summary_stats(id, [])
        basin = Basins.get(id)
        name = if basin, do: basin.name, else: id
        {:ok,
         %{
           basin_id: id,
           basin_name: name,
           observed_value: Helpers.to_float(basin_row && basin_row.observed_value),
           historical_average: Helpers.to_float(basin_row && basin_row.historical_average),
           dams: Enum.map(dam_stats, &Helpers.format_basin_dam/1)
         }}
      rescue
        _ -> {:error, "Basin not found"}
      end
    else
      {:error, "Provide basin_id or basin_name"}
    end
  end

  def exec_list_basins(args) do
    usage = Helpers.get_list(args, "usage_types") || []
    stats = Basins.summary_stats(usage)
    {:ok, Enum.map(stats, &Helpers.format_basin_summary/1)}
  end

  def exec_get_basin_dams(%{"basin_id" => id} = args) when is_binary(id) do
    usage = Helpers.get_list(args, "usage_types") || []
    stats = Basins.summary_stats(id, usage)
    {:ok, Enum.map(stats, &Helpers.format_basin_dam/1)}
  end

  def exec_get_basin_dams(args) do
    id = args["basin_id"]
    usage = Helpers.get_list(args, "usage_types") || []
    if id do
      stats = Basins.summary_stats(id, usage)
      {:ok, Enum.map(stats, &Helpers.format_basin_dam/1)}
    else
      {:error, "basin_id is required"}
    end
  end

  def exec_get_basin_storage_evolution(%{"basin_id" => id} = args) do
    period = args["period"] || 30
    stats = Basins.daily_stats_for_basin(id, [], period)
    {:ok, stats}
  end

  def exec_get_basin_storage_evolution(args) do
    id = args["basin_id"]
    period = args["period"] || 30
    if id do
      stats = Basins.daily_stats_for_basin(id, [], period)
      {:ok, stats}
    else
      {:error, "basin_id is required"}
    end
  end
end
