defmodule BarragensptWeb.BasinController do
  use BarragensptWeb, :controller
  alias Barragenspt.Hydrometrics.Basins
  alias Barragenspt.Models.Infoagua.Alert
  alias Barragenspt.Repo

  def index(conn, %{"country" => "pt"}) do
    basins_raw = Basins.summary_stats([])

    alerts =
      Alert
      |> Repo.all()
      |> Enum.map(fn alert -> {to_string(alert.basin_id_internal), alert_payload(alert)} end)
      |> Map.new()

    basins =
      Enum.map(basins_raw, fn basin ->
        basin
        |> Map.put(:alert, Map.get(alerts, to_string(basin.id), default_alert()))
        |> Map.put(:country, "pt")
      end)

    render(conn, "index.json", basins: basins)
  end

  def index(conn, %{"country" => "es"}) do
    basins_raw = Barragenspt.Hydrometrics.EmbalsesNet.basins_info()

    basins =
      Enum.map(basins_raw, fn %{
                                id: id,
                                basin_name: name,
                                current_pct: current_storage,
                                capacity_color: capacity_color
                              } ->
        %{
          id: to_string(id),
          name: name |> String.downcase() |> String.replace(" ", "_"),
          current_storage: current_storage,
          average_historic_value: 0,
          capacity_color: capacity_color,
          country: "es",
          alert: default_alert()
        }
      end)

    render(conn, "index.json", basins: basins)
  end

  defp alert_payload(alert) do
    %{
      basin_id: alert.basin_id,
      basin_id_internal: alert.basin_id_internal,
      color: alert.color,
      last_update: alert.last_update,
      name: alert.name,
      snirh_source_id: alert.snirh_source_id,
      station_id: alert.station_id,
      value: alert.value
    }
  end

  defp default_alert do
    %{
      color: "#2eb1d3",
      value: "Sem alertas ativos"
    }
  end
end
