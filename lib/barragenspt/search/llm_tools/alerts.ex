defmodule Barragenspt.Search.LLMTools.Alerts do
  @moduledoc false

  alias Barragenspt.Services.InfoAgua

  def exec("get_flood_alerts", args), do: exec_get_flood_alerts(args)
  def exec(_, _), do: nil

  def exec_get_flood_alerts(_) do
    case InfoAgua.fetch_alerts_map() do
      {:ok, data} -> {:ok, %{alerts: data}}
      {:error, reason} -> {:error, "Failed to fetch alerts: #{inspect(reason)}"}
    end
  end
end
