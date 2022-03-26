defmodule BarragensptWeb.BasinController do
  use BarragensptWeb, :controller
  alias Barragenspt.Mappers.Colors
  alias Barragenspt.Hydrometrics.Basins

  def index(conn, _params) do
    basins =
      Enum.map(Basins.summary_stats(), fn {basin_id, name, current_storage, value} ->
        %{
          id: basin_id,
          name: name,
          current_storage: current_storage,
          average_historic_value: value,
          capacity_color: current_storage |> Decimal.to_float() |> Colors.lookup_capacity()
        }
      end)

    render(conn, "index.json", basins: basins)
  end
end
