defmodule Barragenspt.Hydrometrics.LegendMapping do
  use Ecto.Schema
  import Ecto.Changeset

  schema "legend_mapping" do
    field :meteo_index, :string
    field :color_hex, :string
    field :color_xyz, :string
    field :min_value, :decimal
    field :max_value, :decimal
    field :variant, :string
  end

  @doc false
  def changeset(dam, attrs) do
    dam
    |> cast(attrs, [:meteo_index, :color_hex, :color_xyz, :min_value, :max_value, :variant])
    |> validate_required([:color_hex, :color_xyz])
  end
end
