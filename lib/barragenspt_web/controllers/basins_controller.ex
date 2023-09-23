defmodule BarragensptWeb.BasinController do
  use BarragensptWeb, :controller
  alias Barragenspt.Mappers.Colors
  alias Barragenspt.Hydrometrics.Basins

  def index(conn, %{"country" => "pt"}) do
    basins_raw = Basins.summary_stats([])

    basins =
      Enum.map(basins_raw, fn {basin_id, name, current_storage, value} ->
        %{
          id: basin_id,
          name: String.downcase(name),
          current_storage: current_storage,
          average_historic_value: value,
          capacity_color: current_storage |> Decimal.to_float() |> Colors.lookup_capacity(),
          country: "pt"
        }
      end)

    render(conn, "index.json", basins: basins)
  end

  def index(conn, %{"country" => "es"}) do
    basins_raw = Barragenspt.Hydrometrics.EmbalsesNet.basins_info()

    basins =
      Enum.map(basins_raw, fn %{basin_name: name, current_pct: current_storage} ->
        %{
          id: to_string(:rand.uniform(9_999_999_999)),
          name: name |> String.downcase() |> String.replace(" ", "_"),
          current_storage: current_storage,
          average_historic_value: 0,
          capacity_color:
            current_storage
            |> Decimal.parse()
            |> then(fn {dc, ""} -> dc end)
            |> Decimal.to_float()
            |> Colors.lookup_capacity(),
          country: "es"
        }
      end)

    render(conn, "index.json", basins: basins)
  end
end
