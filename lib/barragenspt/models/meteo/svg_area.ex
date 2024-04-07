defmodule Barragenspt.Models.Meteo.SvgArea do
  use Ecto.Schema
  import Ecto.Changeset

  schema "svg_area" do
    field :name, :string
    field :svg_path, :string
    field :svg_path_hash, :string
    field :area, :decimal
    field :geographic_area_type, :string

    timestamps()
  end

  @doc false
  def changeset(dam, attrs) do
    dam
    |> cast(attrs, [:name, :svg_path, :area, :svg_path_hash, :geographic_area_type])
    |> validate_required([:svg_path, :area, :svg_path_hash, :geographic_area_type])
  end
end
