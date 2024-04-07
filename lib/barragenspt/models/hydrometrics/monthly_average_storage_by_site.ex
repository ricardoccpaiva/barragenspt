defmodule Barragenspt.Models.Hydrometrics.MonthlyAverageStorageBySite do
  use Ecto.Schema

  @primary_key false
  schema "monthly_average_storage_by_site" do
    field :period, :integer
    field :site_id, :string
    field :value, :decimal
  end
end
