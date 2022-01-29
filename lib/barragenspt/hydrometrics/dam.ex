defmodule Barragenspt.Hydrometrics.Dam do
  use Ecto.Schema
  import Ecto.Changeset

  schema "dam" do
    field :basin, :string
    field :basin_id, :integer
    field :code, :string
    field :metadata, :map
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(dam, attrs) do
    dam
    |> cast(attrs, [:code, :name, :basin, :basin_id, :metadata])
    |> validate_required([:code, :name, :basin, :basin_id, :metadata])
  end
end
