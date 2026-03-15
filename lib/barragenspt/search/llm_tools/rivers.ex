defmodule Barragenspt.Search.LLMTools.Rivers do
  @moduledoc false

  alias Barragenspt.Hydrometrics.Dams
  alias Barragenspt.Search.LLMTools.Helpers

  def exec("search_rivers", args), do: exec_search_rivers(args)
  def exec("get_river_dams", args), do: exec_get_river_dams(args)
  def exec(_, _), do: nil

  def exec_search_rivers(%{"query" => q}) when is_binary(q) and q != "" do
    all = Dams.get_river_names()
    q_lower = String.downcase(q)
    matches =
      Enum.filter(all, fn r ->
        String.contains?(String.downcase(r.river_display_name || r.river_name || ""), q_lower)
      end)
    {:ok,
     Enum.map(matches, &%{
       river_name: &1.river_name,
       river_display_name: &1.river_display_name,
       basin_id: &1.basin_id
     })}
  end

  def exec_search_rivers(_), do: {:error, "query is required"}

  def exec_get_river_dams(%{"river_name" => name}) when is_binary(name) do
    dams = Dams.get_dams_by_river(name)
    if dams == [] do
      {:ok, %{river_name: name, dams: [], message: "No dams found for this river"}}
    else
      enriched =
        Enum.map(dams, fn %{site_id: sid, basin_id: bid} ->
          info = Dams.get(sid)
          %{
            dam_id: sid,
            dam_name: info.site_name,
            basin_id: bid,
            current_storage_pct: Helpers.to_float(info.current_storage_pct)
          }
        end)
      {:ok, %{river_name: name, dams: enriched}}
    end
  rescue
    _ -> {:ok, %{river_name: name, dams: []}}
  end

  def exec_get_river_dams(_), do: {:error, "river_name is required"}
end
