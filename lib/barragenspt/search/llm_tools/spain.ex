defmodule Barragenspt.Search.LLMTools.Spain do
  @moduledoc false

  alias Barragenspt.Hydrometrics.EmbalsesNet

  def exec("get_spain_basins", args), do: exec_get_spain_basins(args)
  def exec("get_spain_basin_info", args), do: exec_get_spain_basin_info(args)
  def exec(_, _), do: nil

  def exec_get_spain_basins(_) do
    basins = EmbalsesNet.basins_info()
    {:ok, Enum.map(basins, &%{id: &1.id, basin_name: &1.basin_name, current_pct: &1.current_pct})}
  end

  def exec_get_spain_basin_info(%{"basin_id" => id}) do
    case EmbalsesNet.basin_info(id) do
      nil -> {:error, "Spanish basin not found"}
      info -> {:ok, Map.new(info, fn {k, v} -> {to_string(k), v} end)}
    end
  end

  def exec_get_spain_basin_info(_), do: {:error, "basin_id is required"}
end
