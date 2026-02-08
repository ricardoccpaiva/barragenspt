defmodule BarragensptWeb.DamView do
  use BarragensptWeb, :view
  alias BarragensptWeb.DamView

  def render("dam_minified.json", %{dams: dams}) do
    render_many(dams, DamView, "dam_minified_entry.json")
  end

  def render("dam_minified_entry.json", %{dam: dam}) do
    %{
      id: dam.id,
      name: dam.name,
      current_storage:
        dam.current_storage |> Decimal.new() |> Decimal.round(2) |> Decimal.to_float()
    }
  end

  def render("stats.json", %{stats: stats}) do
    render_many(stats, DamView, "stats_entry.json")
  end

  def render("stats_entry.json", %{dam: stats}) do
    %{
      date: stats.date,
      observed_value: stats.observed_value,
      historical_average: stats.historical_average,
      discharge_value: stats.discharge_value
    }
  end

  def render("index.json", %{dams: dams}) do
    render_many(dams, DamView, "dam.json")
  end

  def render("show.json", %{dam: dam}) do
    render_one(dam, DamView, "dam_detail.json")
  end

  def render("dam.json", %{dam: dam}) do
    %{
      basin_id: dam.basin_id,
      site_id: dam.site_id,
      dam_name: dam.dam_name,
      basin_name: dam.basin_name,
      current_storage: dam.current_storage,
      colected_at: dam.colected_at,
      lat: dam.lat,
      lon: dam.lon,
      elevation: dam.elevation,
      useful_capacity: dam.useful_capacity,
      total_capacity: dam.total_capacity
    }
  end

  def render("dam_detail.json", %{dam: dam}) do
    %{
      basin_id: dam.basin_id,
      site_id: dam.site_id,
      dam_name: dam.dam_name,
      basin_name: dam.basin_name,
      current_storage: dam.current_storage,
      colected_at: dam.colected_at,
      lat: dam.lat,
      lon: dam.lon,
      elevation: dam.elevation,
      useful_capacity: dam.useful_capacity,
      total_capacity: dam.total_capacity,
      metadata: dam.metadata
    }
  end
end
