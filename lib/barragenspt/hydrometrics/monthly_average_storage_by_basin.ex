defmodule Barragenspt.Hydrometrics.MonthlyAverageStorageByBasin do
  use Ecto.Schema

  @primary_key false
  schema "monthly_average_storage_by_basin" do
    field :period, :integer
    field :basin_id, :string
    field :value, :decimal
  end
end
