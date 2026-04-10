defmodule BarragensptWeb.Api.BasinsView do
  use BarragensptWeb, :view

  def render("index.json", %{basins: basins}) do
    %{
      data: Enum.map(basins, &basin/1),
      links: %{
        self: "/api/basins",
        basin: "/api/basins/{id}"
      }
    }
  end

  def render("show.json", %{basin: basin}) do
    %{
      data: basin(basin),
      links: %{dams: "/api/basins/#{basin.id}/dams"}
    }
  end

  def render("dams.json", %{basin_id: basin_id, dams: dams}) do
    %{
      data: Enum.map(dams, &dam_in_basin/1),
      links: %{
        self: "/api/basins/#{basin_id}/dams",
        basin: "/api/basins/#{basin_id}",
        dam: "/api/dams/{id}"
      }
    }
  end

  defp dam_in_basin(%{
         site_id: id,
         site_name: name,
         current_storage_volume: cur,
         historical_average_volume: hist,
         colected_at: at,
         usage_types: usage_types
       }) do
    %{
      id: id,
      name: name,
      current_storage_volume: json_number(cur),
      historical_average_volume: json_number(hist),
      collected_at: collected_at_iso8601(at),
      usage_types: usage_types
    }
  end

  defp json_number(nil), do: nil

  defp json_number(%Decimal{} = d) do
    d |> Decimal.round(0) |> Decimal.to_integer()
  end

  defp json_number(n) when is_integer(n), do: n
  defp json_number(n) when is_float(n), do: round(n)

  defp collected_at_iso8601(%NaiveDateTime{} = ndt) do
    ndt
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_iso8601()
  end

  defp collected_at_iso8601(nil), do: nil

  defp basin(%{
         id: id,
         name: name,
         current_storage_volume: current,
         historical_average_volume: historical,
         total_capacity: total_capacity
       }) do
    %{
      id: to_string(id),
      name: name,
      current_storage_volume: current,
      historical_average_volume: historical,
      total_capacity: total_capacity
    }
  end
end
