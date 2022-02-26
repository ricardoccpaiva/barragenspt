defmodule Barragenspt.Hydrometrics.DataPoint do
  use Ecto.Schema
  import Ecto.Changeset

  schema "data_points" do
    field :basin_id, :string
    field :colected_at, :naive_datetime
    field :dam_code, :string
    field :param_id, :string
    field :param_name, :string
    field :site_id, :string
    field :value, :decimal

    timestamps()
  end

  @doc false
  def changeset(data_point, attrs) do
    data_point
    |> cast(attrs, [:param_name, :param_id, :dam_code, :site_id, :basin_id, :value, :colected_at])
    |> validate_required([
      :param_name,
      :param_id,
      :dam_code,
      :site_id,
      :basin_id,
      :value,
      :colected_at
    ])
  end
end
