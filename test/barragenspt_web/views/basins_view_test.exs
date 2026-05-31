defmodule BarragensptWeb.Api.BasinsViewTest do
  use ExUnit.Case, async: true

  alias BarragensptWeb.Api.BasinsView

  test "index response includes self link with includeSpain=true and country fields" do
    basins = [
      %{
        id: "1",
        name: "Rio Mondego",
        observed_value: 59.5,
        current_storage_volume: 1_250_000,
        historical_average_volume: 1_180_000,
        total_capacity: 2_100_000
      },
      %{
        id: "es-1",
        name: "duero",
        country: "es",
        current_storage_percent: 72.1,
        current_storage_volume: nil,
        historical_average_volume: nil,
        total_capacity: nil
      }
    ]

    payload = BasinsView.render("index.json", %{basins: basins, include_spain: true})

    assert payload.links.self == "/api/basins?includeSpain=true"
    assert payload.links.basin == "/api/basins/{id}"

    assert payload.data == [
             %{
               id: "1",
               name: "Rio Mondego",
               country: "pt",
               current_storage_percent: 59.5,
               current_storage_volume: 1_250_000,
               historical_average_volume: 1_180_000,
               total_capacity: 2_100_000
             },
             %{
               id: "es-1",
               name: "duero",
               country: "es",
               current_storage_percent: 72.1,
               current_storage_volume: nil,
               historical_average_volume: nil,
               total_capacity: nil
             }
           ]
  end
end
