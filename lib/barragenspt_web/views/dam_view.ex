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
      site_id: dam.site_id,
      current_storage: dam.current_storage,
      current_storage_color: dam.current_storage_color,
      lat: dam.lat,
      lon: dam.lon
    }
  end
end
