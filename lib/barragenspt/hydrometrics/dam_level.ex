defmodule Barragenspt.Hydrometrics.DamLevel do
  use Ecto.Schema
  import Ecto.Changeset

  schema "dam_level" do
    field :reference_period, :date
    field :reference_period_type, :string
    field :reference_value, :decimal
    field :reference_value_type, :string
    field :dam_id, :id

    timestamps()
  end

  @doc false
  def changeset(dam_level, attrs) do
    dam_level
    |> cast(attrs, [
      :reference_period_type,
      :reference_period,
      :reference_value_type,
      :reference_value
    ])
    |> validate_required([
      :reference_period_type,
      :reference_period,
      :reference_value_type,
      :reference_value
    ])
  end
end
