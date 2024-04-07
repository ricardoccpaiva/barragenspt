defmodule Barragenspt.Models.Hydrometrics.DailyAverageStorageBySite do
  use Ecto.Schema

  @primary_key false
  schema "daily_average_storage_by_site" do
    field :period, :string
    field :site_id, :string
    field :value, :decimal
  end
end
