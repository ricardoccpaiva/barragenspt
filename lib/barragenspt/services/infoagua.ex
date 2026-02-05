defmodule Barragenspt.Services.InfoAgua do
  @moduledoc """
  Fetches and parses DATA_AlertsMap from infoagua cheias page.
  """

  @url "https://infoagua.apambiente.pt/pt/cheias"

  def fetch_alerts_map do
    with {:ok, html} <- fetch_html(),
         {:ok, json} <- extract_alerts_map_json(html),
         {:ok, data} <- Jason.decode(json) do
      {:ok, filter_alerts(data)}
    else
      {:error, _} = error -> error
    end
  end

  def fetch_alerts_map! do
    case fetch_alerts_map() do
      {:ok, data} -> data
      {:error, reason} -> raise "Failed to fetch DATA_AlertsMap: #{inspect(reason)}"
    end
  end

  defp fetch_html do
    case Tesla.get(@url) do
      {:ok, %Tesla.Env{body: body}} when is_binary(body) -> {:ok, body}
      {:ok, %Tesla.Env{body: _}} -> {:error, :invalid_body}
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_alerts_map_json(html) do
    case Regex.run(~r/var\s+DATA_AlertsMap\s*=\s*(\{[\s\S]*?\});/, html, capture: :all_but_first) do
      [json] -> {:ok, json}
      _ -> {:error, :data_alerts_map_not_found}
    end
  end

  defp filter_alerts(data) when is_map(data) do
    data
    |> Map.values()
    |> Enum.map(&filter_alert/1)
  end

  defp filter_alert(alert) when is_map(alert) do
    %{
      "basin_id" => alert["basin_id"],
      "color" => alert["color"],
      "last_update" => alert["last_update"],
      "name" => alert["name"],
      "snirh_source_id" => alert["snirh_source_id"],
      "station_id" => alert["station_id"],
      "value" => alert["value"]
    }
  end

  defp filter_alert(_), do: %{}
end
