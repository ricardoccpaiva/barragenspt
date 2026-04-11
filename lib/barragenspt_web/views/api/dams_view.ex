defmodule BarragensptWeb.Api.DamsView do
  use BarragensptWeb, :view

  def render("dam.json", %{dam: dam, scope: :global}) do
    id = dam.site_id
    basin_id = dam.basin_id

    %{
      data: dam_data(dam),
      links: %{
        self: "/api/dams/#{id}",
        basin: "/api/basins/#{basin_id}",
        collection: "/api/basins/#{basin_id}/dams"
      }
    }
  end

  def render("dam.json", %{basin_id: basin_id, dam: dam}) do
    id = dam.site_id

    %{
      data: dam_data(dam),
      links: %{
        self: "/api/basins/#{basin_id}/dams/#{id}",
        basin: "/api/basins/#{basin_id}",
        collection: "/api/basins/#{basin_id}/dams"
      }
    }
  end

  def dam_data(dam) do
    id = Map.get(dam, :site_id) || Map.get(dam, :id)
    name = Map.get(dam, :site_name) || Map.get(dam, :name)
    cur = Map.get(dam, :current_storage_volume)
    quota = Map.get(dam, :current_storage_quota)
    at = Map.get(dam, :colected_at)
    usage_types = Map.get(dam, :usage_types)

    usage_types_value =
      case usage_types do
        list when is_list(list) -> list
        other -> usage_types_list(other)
      end

    base = %{
      id: id,
      name: name,
      current_storage_volume: json_number(cur),
      current_storage_quota: json_storage_quota(quota),
      collected_at: collected_at_iso8601(at),
      usage_types: usage_types_value
    }

    case Map.get(dam, :historical_average_volume) do
      nil -> base
      hist -> Map.put(base, :historical_average_volume, json_number(hist))
    end
  end

  defp usage_types_list(list) when is_list(list), do: list
  defp usage_types_list(nil), do: []

  defp usage_types_list(csv) when is_binary(csv) do
    csv
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp json_number(nil), do: nil

  defp json_number(%Decimal{} = d) do
    d |> Decimal.round(0) |> Decimal.to_integer()
  end

  defp json_number(n) when is_integer(n), do: n
  defp json_number(n) when is_float(n), do: round(n)

  defp json_storage_quota(nil), do: nil

  defp json_storage_quota(%Decimal{} = d) do
    d |> Decimal.round(2) |> Decimal.to_float()
  end

  defp json_storage_quota(n) when is_float(n), do: Float.round(n, 2)
  defp json_storage_quota(n) when is_integer(n), do: n * 1.0

  defp collected_at_iso8601(%NaiveDateTime{} = ndt) do
    ndt
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_iso8601()
  end

  defp collected_at_iso8601(nil), do: nil
end
