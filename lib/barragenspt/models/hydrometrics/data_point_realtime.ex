defmodule Barragenspt.Models.Hydrometrics.DataPointRealtime do
  @moduledoc """
  Schema for real-time data points. Mirrors the structure of DataPoint
  but stored in a separate table for real-time (e.g. last hour / streaming) data.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "data_points_realtime" do
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
  def changeset(data_point_realtime, attrs) do
    data_point_realtime
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
