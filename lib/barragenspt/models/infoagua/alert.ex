defmodule Barragenspt.Models.Infoagua.Alert do
  use Ecto.Schema
  import Ecto.Changeset

  schema "infoagua_alerts" do
    field :basin_id, :integer
    field :basin_id_internal, :string
    field :color, :string
    field :last_update, :naive_datetime
    field :name, :string
    field :snirh_source_id, :integer
    field :station_id, :integer
    field :value, :string

    timestamps()
  end

  @doc false
  def changeset(alert, attrs) do
    alert
    |> cast(attrs, [
      :basin_id,
      :basin_id_internal,
      :color,
      :last_update,
      :name,
      :snirh_source_id,
      :station_id,
      :value
    ])
    |> validate_required([
      :basin_id,
      :color,
      :last_update,
      :name,
      :snirh_source_id,
      :station_id,
      :value
    ])
  end
end
