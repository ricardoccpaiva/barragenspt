defmodule BarragensptWeb.Api.BasinsView do
  use BarragensptWeb, :view

  def render("index.json", %{basins: basins}) do
    %{data: Enum.map(basins, &basin/1)}
  end

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
