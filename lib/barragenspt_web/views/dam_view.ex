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
      basin_id: dam.basin_id,
      site_id: dam.site_id,
      dam_name: dam.dam_name,
      basin_name: dam.basin_name,
      current_storage: dam.current_storage,
      current_storage_color: dam.current_storage_color,
      colected_at: dam.colected_at,
      lat: dam.lat,
      lon: dam.lon,
      elevation: dam.elevation,
      useful_capacity: dam.useful_capacity,
      total_capacity: dam.total_capacity
    }
  end
end
