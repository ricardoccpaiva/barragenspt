defmodule Barragenspt.Models.Hydrometrics.DamUsage do
  use Ecto.Schema
  import Ecto.Changeset

  schema "dam_usage" do
    field :site_id, :string
    field :usage_name, :string

    timestamps()
  end

  @doc false
  def changeset(dam_usage, attrs) do
    dam_usage
    |> cast(attrs, [:site_id, :usage_name])
    |> validate_required([:site_id, :usage_name])
  end
end
