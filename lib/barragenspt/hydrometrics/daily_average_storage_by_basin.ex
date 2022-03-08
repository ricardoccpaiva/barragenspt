defmodule Barragenspt.Hydrometrics.DailyAverageStorageByBasin do
  use Ecto.Schema

  @primary_key false
  schema "daily_average_storage_by_basin" do
    field :period, :string
    field :basin_id, :string
    field :value, :decimal
  end
end
