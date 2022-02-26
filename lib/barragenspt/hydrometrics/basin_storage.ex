defmodule Barragenspt.Hydrometrics.BasinStorage do
  use Ecto.Schema

  @primary_key false
  schema "basin_storage" do
    field :id, :string
    field :name, :string
    field :current_storage, :decimal
  end
end
