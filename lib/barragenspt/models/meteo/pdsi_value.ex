defmodule Barragenspt.Models.Meteo.PdsiValue do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pdsi_value" do
    field :svg_path_hash, :string
    field :color_hex, :string
    field :year, :integer
    field :month, :integer
    field :geographic_area_type, :string

    timestamps()
  end

  @doc false
  def changeset(dam, attrs) do
    dam
    |> cast(attrs, [:svg_path_hash, :color_hex, :year, :month, :geographic_area_type])
    |> validate_required([:svg_path_hash, :color_hex, :year, :month, :geographic_area_type])
  end
end
