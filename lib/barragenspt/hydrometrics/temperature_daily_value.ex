defmodule Barragenspt.Hydrometrics.TemperatureDailyValue do
  use Ecto.Schema
  import Ecto.Changeset

  schema "temperature_daily_value" do
    field :svg_path_hash, :string
    field :color_hex, :string
    field :date, :date
    field :geographic_area_type, :string
    field :layer, :string

    timestamps()
  end

  @doc false
  def changeset(dam, attrs) do
    dam
    |> cast(attrs, [:svg_path_hash, :color_hex, :date, :geographic_area_type, :layer])
    |> validate_required([:svg_path_hash, :color_hex, :date, :geographic_area_type, :layer])
  end
end
