defmodule BarragensptWeb.Api.BasinsView do
  use BarragensptWeb, :view

  alias BarragensptWeb.Api.DamsView

  def render("index.json", %{basins: basins, include_spain: include_spain}) do
    %{
      data: Enum.map(basins, &basin/1),
      links: %{
        self: self_link(include_spain),
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
      data: Enum.map(dams, &DamsView.dam_data/1),
      links: %{
        self: "/api/basins/#{basin_id}/dams",
        basin: "/api/basins/#{basin_id}",
        dam: "/api/basins/#{basin_id}/dams/{site_id}"
      }
    }
  end

  defp basin(
         %{
           id: id,
           name: name,
           current_storage_volume: current,
           historical_average_volume: historical,
           total_capacity: total_capacity
         } = basin
       ) do
    %{
      id: to_string(id),
      name: name,
      country: Map.get(basin, :country, "pt"),
      current_storage_percent:
        Map.get(basin, :current_storage_percent) || Map.get(basin, :observed_value),
      current_storage_volume: current,
      historical_average_volume: historical,
      total_capacity: total_capacity
    }
  end

  defp self_link(true), do: "/api/basins?includeSpain=true"
  defp self_link(_), do: "/api/basins"
end
