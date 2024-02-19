defmodule Barragenspt.Hydrometrics.PrecipitationLegendMapping do
  use Ecto.Schema
  import Ecto.Changeset

  schema "precipitation_legend_mapping" do
    field :color_hex, :string
    field :color_xyz, :string
    field :mean_value, :decimal
  end

  @doc false
  def changeset(dam, attrs) do
    dam
    |> cast(attrs, [:color_hex, :color_xyz, :mean_value])
    |> validate_required([:color_hex, :color_xyz, :mean_value])
  end
end
