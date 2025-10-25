defmodule BarragensptWeb.DamDataView do
  use BarragensptWeb, :view
  alias BarragensptWeb.DamDataView

  def render("show.json", %{dam_data: dam_data}) do
    %{data: render_many(dam_data, DamDataView, "data_entry.json")}
  end

  def render("data_entry.json", %{dam_data: entry}) do
    %{
      basin: entry.basin,
      basin_id: entry[:basin_id],
      date: entry.date,
      value: entry.value
    }
  end
end
