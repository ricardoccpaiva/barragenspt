defmodule Barragenspt.Workers.InfoaguaAlertsRefresh do
  use Oban.Worker, queue: :meteo_data
  require Logger

  alias Barragenspt.Repo
  alias Barragenspt.Models.Infoagua.Alert
  alias Barragenspt.Services.InfoAgua

  @basins_csv_path Path.expand("../../../resources/basins_pt.csv", __DIR__)

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: :ok | {:error, any()}
  def perform(%Oban.Job{}) do
    basins_map = load_basins_map()

    case InfoAgua.fetch_alerts_map() do
      {:ok, alerts} when is_list(alerts) ->
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        rows =
          alerts
          |> Enum.map(&build_row(&1, now, basins_map))
          |> Enum.reject(&is_nil/1)

        Repo.transaction(fn ->
          Repo.insert_all(Alert, rows)
        end)

        Logger.info("Infoagua alerts refreshed: #{Enum.count(rows)} rows")
        :ok

      {:ok, _} ->
        Logger.warning("Infoagua alerts refresh returned unexpected payload")
        :ok

      {:error, reason} ->
        Logger.error("Infoagua alerts refresh failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_row(alert, now, basins_map) when is_map(alert) do
    with {:ok, last_update} <- parse_last_update(alert["last_update"]) do
      basin_id_internal = Map.get(basins_map, normalize_basin_name(alert["name"]))

      %{
        basin_id: alert["basin_id"],
        basin_id_internal: basin_id_internal,
        color: alert["color"],
        last_update: last_update,
        name: alert["name"],
        snirh_source_id: alert["snirh_source_id"],
        station_id: alert["station_id"],
        value: alert["value"],
        inserted_at: now,
        updated_at: now
      }
    else
      _ -> nil
    end
  end

  defp build_row(_alert, _now, _basins_map), do: nil

  defp parse_last_update(nil), do: {:error, :missing_last_update}

  defp parse_last_update(value) when is_binary(value) do
    value
    |> String.replace(" ", "T")
    |> NaiveDateTime.from_iso8601()
  end

  defp load_basins_map do
    case File.read(@basins_csv_path) do
      {:ok, contents} ->
        contents
        |> NimbleCSV.RFC4180.parse_string()
        |> Enum.drop(1)
        |> Enum.reduce(%{}, fn row, acc ->
          case row do
            [id, name] ->
              Map.put(acc, normalize_basin_name(name), id)

            [id, name, _] ->
              Map.put(acc, normalize_basin_name(name), id)

            _ ->
              acc
          end
        end)

      {:error, _} ->
        %{}
    end
  end

  defp normalize_basin_name(nil), do: nil

  defp normalize_basin_name(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.downcase()
  end
end
