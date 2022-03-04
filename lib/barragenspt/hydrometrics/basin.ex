defmodule Barragenspt.Hydrometrics.Basin do
  use Ecto.Schema
  import Ecto.Query

  @primary_key false
  schema "basins" do
    field :id, :string
    field :name, :string
  end

  def get(id) do
    query = from(b in Barragenspt.Hydrometrics.Basin, where: b.id == ^id)

    Barragenspt.Repo.one(query)
  end
end
