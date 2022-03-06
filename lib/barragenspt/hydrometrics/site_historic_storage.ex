defmodule Barragenspt.Hydrometrics.SiteHistoricStorage do
  use Ecto.Schema

  @primary_key false
  schema "site_historic_storage" do
    field :month, :integer
    field :site_id, :string
    field :value, :decimal
  end
end
