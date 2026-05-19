defmodule Barragenspt.Models.Hydrometrics.DataPointWithDam do
  @moduledoc """
  Read-only mapping to the `data_points_with_dam` SQL view:
  `dam` joined to `data_points` on `site_id` (and matching `basin_id`).

  `site_id` and `basin_id` in the view come from `data_points` so filters can use
  base-table indexes; `dam_name`, `basin`, and `river` still come from `dam`.
  """
  use Ecto.Schema

  @derive {
    Flop.Schema,
    filterable: [
      :dam_name,
      :basin,
      :basin_id,
      :site_id,
      :param_id,
      :param_name,
      :colected_at
    ],
    sortable: [
      :id,
      :colected_at,
      :value,
      :param_name,
      :dam_name,
      :basin
    ],
    default_limit: 10,
    max_limit: 100,
    pagination_types: [:page],
    default_pagination_type: :page,
    default_order: %{
      order_by: [:colected_at, :id],
      order_directions: [:desc, :desc]
    }
  }

  @primary_key {:id, :id, autogenerate: false}
  schema "data_points_with_dam" do
    field :site_id, :string
    field :basin_id, :string
    field :dam_name, :string
    field :basin, :string
    field :river, :string
    field :param_id, :string
    field :param_name, :string
    field :value, :decimal
    field :colected_at, :naive_datetime
  end
end
