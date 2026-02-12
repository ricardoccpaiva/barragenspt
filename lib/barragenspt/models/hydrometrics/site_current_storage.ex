defmodule Barragenspt.Models.Hydrometrics.SiteCurrentStorage do
  use Ecto.Schema

  @primary_key false
  schema "site_current_storage" do
    field :site_id, :string
    field :current_storage_value, :decimal
    field :current_storage_pct, :decimal
    field :colected_at, :naive_datetime
  end
end
