defmodule Barragenspt.Search.LLMTools.Dams do
  @moduledoc false

  alias Barragenspt.Hydrometrics.{Dams, DamChartSeries}
  alias Barragenspt.Search.LLMTools.Helpers

  def exec("get_dam_storage", args), do: exec_get_dam_storage(args)
  def exec("get_dams_summary_stats", args), do: exec_get_dams_summary_stats(args)
  def exec("search_dams", args), do: exec_search_dams(args)
  def exec("get_dam_info", args), do: exec_get_dam_info(args)
  def exec("get_dams_by_usage_type", args), do: exec_get_dams_by_usage_type(args)
  def exec("get_dam_storage_trend", args), do: exec_get_dam_storage_trend(args)
  def exec("get_dam_realtime", args), do: exec_get_dam_realtime(args)
  def exec("compare_dams", args), do: exec_compare_dams(args)
  def exec(_, _), do: nil

  def exec_get_dams_summary_stats(_) do
    stats = Dams.summary_stats()
    {:ok,
     %{
       dams:
         Enum.map(stats, fn s ->
           %{
             dam_id: s.site_id,
             dam_name: s.site_name,
             basin_name: s.basin_name,
             current_storage_pct: Helpers.to_float(s.observed_value),
             historical_average_pct: Helpers.to_float(s.historical_average),
             total_capacity: s.total_capacity,
             colected_at: Helpers.format_datetime(s.colected_at)
           }
         end)
     }}
  end

  def exec_get_dam_storage(%{"dam_name" => name}) when is_binary(name) and name != "" do
    case Helpers.resolve_dam_by_name(name) do
      nil -> {:error, "Dam not found: #{name}"}
      site_id -> exec_get_dam_info(%{"dam_id" => site_id})
    end
  end

  def exec_get_dam_storage(_), do: {:error, "dam_name is required"}

  def exec_search_dams(%{"query" => q} = args) when is_binary(q) and q != "" do
    usage = Helpers.get_list(args, "usage_types") || []
    results = Dams.search(q, usage)
    {:ok, Enum.map(results, &Helpers.format_dam_search/1)}
  end

  def exec_search_dams(_), do: {:error, "query is required"}

  def exec_get_dam_info(args) do
    dam_id = args["dam_id"]
    dam_name = args["dam_name"]

    site_id =
      cond do
        is_binary(dam_id) and dam_id != "" -> dam_id
        is_binary(dam_name) and dam_name != "" -> Helpers.resolve_dam_by_name(dam_name)
        true -> nil
      end

    if site_id do
      try do
        info = Dams.get(site_id)
        {:ok, Helpers.format_dam_info(info)}
      rescue
        _ -> {:error, "Dam not found"}
      end
    else
      {:error, "Provide dam_id or dam_name"}
    end
  end

  def exec_get_dams_by_usage_type(%{"usage_types" => types})
      when is_list(types) and types != [] do
    results = Dams.current_storage(types)
    {:ok, Enum.map(results, &Helpers.format_dam_storage_item/1)}
  end

  def exec_get_dams_by_usage_type(_), do: {:error, "usage_types (array) is required"}

  def exec_get_dam_storage_trend(%{"dam_id" => id} = args) when is_binary(id) do
    period = args["period"] || "d30"
    period = if period in ~w(d7 d14 d30 d60 d180), do: period, else: "d30"
    series = DamChartSeries.storage_series(id, period)
    {:ok, series}
  end

  def exec_get_dam_storage_trend(args) do
    period = args["period"] || "d30"
    period = if period in ~w(d7 d14 d30 d60 d180), do: period, else: "d30"
    id = args["dam_id"]

    if id do
      series = DamChartSeries.storage_series(id, period)
      {:ok, series}
    else
      {:error, "dam_id is required"}
    end
  end

  def exec_get_dam_realtime(%{"dam_id" => id}) when is_binary(id) do
    try do
      data = Dams.realtime_series(id)
      {:ok, %{realtime: data}}
    rescue
      _ -> {:error, "Dam not found"}
    end
  end

  def exec_get_dam_realtime(_), do: {:error, "dam_id is required"}

  def exec_compare_dams(%{"dam_names" => names}) when is_list(names) do
    names = Enum.take(Enum.filter(names, &is_binary/1), 5)
    if length(names) < 2, do: {:error, "Provide 2-5 dam names"}, else: do_compare_dams(names)
  end

  def exec_compare_dams(_), do: {:error, "dam_names (array of 2-5 names) is required"}

  defp do_compare_dams(names) do
    results =
      Enum.map(names, fn name ->
        case Helpers.resolve_dam_by_name(name) do
          nil ->
            %{name: name, error: "not found"}

          site_id ->
            info = Dams.get(site_id)

            %{
              name: info.site_name,
              dam_id: info.site_id,
              basin: info.basin_name,
              current_storage_pct: Helpers.to_float(info.current_storage_pct)
            }
        end
      end)

    {:ok, %{dams: results}}
  end
end
