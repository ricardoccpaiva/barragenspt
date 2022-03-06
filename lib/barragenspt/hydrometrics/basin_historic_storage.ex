defmodule Barragenspt.Hydrometrics.BasinHistoricStorage do
  use Ecto.Schema

  @primary_key false
  schema "basin_historic_storage" do
    field :month, :integer
    field :basin_id, :string
    field :value, :decimal
  end
end
