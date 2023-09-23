defmodule BarragensptWeb.BasinView do
  use BarragensptWeb, :view
  alias BarragensptWeb.BasinView

  def render("index.json", %{basins: basins}) do
    %{data: render_many(basins, BasinView, "basin.json")}
  end

  def render("show.json", %{basin: basin}) do
    %{data: render_one(basin, BasinView, "basin.json")}
  end

  def render("basin.json", %{basin: basin}) do
    %{
      id: basin.id,
      name: basin.name,
      current_storage: basin.current_storage,
      capacity_color: basin.capacity_color,
      country: basin.country
    }
  end
end
