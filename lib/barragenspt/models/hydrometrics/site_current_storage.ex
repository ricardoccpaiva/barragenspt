defmodule Barragenspt.Models.Hydrometrics.SiteCurrentStorage do
  use Ecto.Schema

  @primary_key false
  schema "site_current_storage" do
    field :basin_id, :string
    field :site_id, :string
    field :site_name, :string
    field :basin_name, :string
    field :current_storage, :decimal
    field :colected_at, :naive_datetime
  end
end
