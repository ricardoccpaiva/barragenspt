defmodule BarragensptWeb.DamView do
  use BarragensptWeb, :view
  alias BarragensptWeb.DamView

  def render("index.json", %{dams: dams}) do
    %{data: render_many(dams, DamView, "dam.json")}
  end

  def render("show.json", %{dam: dam}) do
    %{data: render_one(dam, DamView, "dam.json")}
  end

  def render("dam.json", %{dam: dam}) do
    %{
      id: dam.basin_id,
      lat: dam.lat,
      lon: dam.lon,
      basin_color: dam.basin_color,
      pct: dam.pct,
      capacity_color: dam.capacity_color
    }
  end
end
