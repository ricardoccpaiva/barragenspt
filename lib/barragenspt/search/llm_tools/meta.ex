defmodule Barragenspt.Search.LLMTools.Meta do
  @moduledoc false

  alias Barragenspt.Hydrometrics.{Dams, Basins}
  alias Barragenspt.Search.LLMTools.Helpers

  def exec("get_usage_types", args), do: exec_get_usage_types(args)
  def exec("get_national_summary", args), do: exec_get_national_summary(args)
  def exec("get_site_info", args), do: exec_get_site_info(args)
  def exec(_, _), do: nil

  def exec_get_usage_types(_) do
    types = Dams.usage_types() |> Enum.map(fn {t} -> t end)
    {:ok, %{usage_types: types}}
  end

  def exec_get_national_summary(args) do
    usage = Helpers.get_list(args, "usage_types") || []
    stats = Basins.summary_stats(usage)
    total_obs = Enum.reduce(stats, 0, fn s, acc -> acc + (Helpers.to_float(s.observed_value) || 0) end)
    total_hist = Enum.reduce(stats, 0, fn s, acc -> acc + (Helpers.to_float(s.historical_average) || 0) end)
    n = max(length(stats), 1)
    {:ok,
     %{
       basin_count: length(stats),
       average_observed_pct: Float.round(total_obs / n, 1),
       average_historical_pct: Float.round(total_hist / n, 1),
       basins: Enum.map(stats, &Helpers.format_basin_summary/1)
     }}
  end

  def exec_get_site_info(_) do
    {:ok,
     %{
       name: "barragens.pt",
       mission: "Visualization and data on Portuguese dams and water storage.",
       data_sources: ["SNIRH", "InfoAgua", "AgroClima", "Embalses.net"],
       features: [
         "Map of Portuguese dams and basins",
         "Current storage levels and trends",
         "Spain basin data (embalses.net)",
         "Weather indices (SMI, precipitation)",
         "Flood/drought alerts"
       ]
     }}
  end
end
