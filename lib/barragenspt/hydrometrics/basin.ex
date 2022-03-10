defmodule Barragenspt.Hydrometrics.Basin do
  use Ecto.Schema

  @primary_key false
  schema "basins" do
    field :id, :string
    field :name, :string
  end
end
