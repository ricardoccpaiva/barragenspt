defmodule BarragensptWeb.DamController do
  use BarragensptWeb, :controller
  alias Barragenspt.Geo.Coordinates
  alias Barragenspt.Hydrometrics.Dams
  require Logger

  def index(conn, %{"search" => value}) do
    dams = Dams.search(value, [])
    render(conn, "dam_minified.json", dams: dams)
  end

  def index(conn, params) do
    dams =
      params
      |> Map.get("usage_types", "")
      |> String.split(",")
      |> Enum.reject(fn usage -> usage == "" end)
      |> Dams.current_storage()
      |> Enum.map(fn d -> build_dam_data(d) end)

    render(conn, "index.json", dams: dams)
  end

  def show(conn, %{"site_id" => site_id}) do
    dam =
      site_id
      |> Dams.get()
      |> build_dam_data()

    render(conn, "show.json", dam: dam)
  end

  def stats(conn, %{"site_id" => site_id, "period" => period, "period_unit" => period_unit}) do
    period = String.to_integer(period)

    stats =
      case period_unit do
        "year" ->
          Dams.monthly_stats(site_id, period)

        "month" ->
          Dams.daily_stats(site_id, period)
      end

    render(conn, "stats.json", stats: stats)
  end

  defp build_dam_data(dam) do
    elementary_Data = %{
      id: dam.site_id,
      basin_id: dam.basin_id,
      site_id: dam.site_id,
      dam_name: dam.site_name,
      basin_name: dam.basin_name,
      current_storage: dam.current_storage,
      colected_at: dam.colected_at,
      metadata: dam.metadata
    }

    coordinates = Coordinates.from_dam(dam.site_id)
    metadata_fields = extract_metadata_fields(dam)

    elementary_Data
    |> Map.merge(coordinates)
    |> Map.merge(metadata_fields)
  end

  defp extract_metadata_fields(dam) do
    metadata = dam.metadata || %{}
    albufeira_data = metadata["Albufeira"] || %{}

    %{
      elevation: get_metadata_value(albufeira_data, "Cota (m)"),
      useful_capacity: get_metadata_value(albufeira_data, "Capacidade útil (dam3)"),
      total_capacity: get_metadata_value(albufeira_data, "Capacidade total (dam3)")
    }
  end

  defp get_metadata_value(data, key) do
    case data[key] do
      nil ->
        nil

      value when is_binary(value) ->
        case Float.parse(value) do
          {float_value, ""} -> float_value
          _ -> value
        end

      value ->
        value
    end
  end
end
