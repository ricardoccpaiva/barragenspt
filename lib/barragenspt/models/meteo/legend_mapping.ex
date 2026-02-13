defmodule Barragenspt.Models.Meteo.LegendMapping do
  @moduledoc """
  Minimal schema for meteo legend color mapping.
  Used by ColorConverter to resolve color_xyz + meteo_index (and optional variant) to hex.
  """
  use Ecto.Schema

  schema "meteo_legend_mapping" do
    field :color_xyz, :string
    field :meteo_index, :integer
    field :variant, :string
    field :color_hex, :string
    timestamps()
  end
end
