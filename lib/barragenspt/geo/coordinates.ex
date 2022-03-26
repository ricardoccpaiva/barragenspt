defmodule Barragenspt.Geo.Coordinates do
  alias Barragenspt.Hydrometrics.Dams

  def from_dam(id) when is_binary(id) do
    dam = Dams.get(id)

    %{
      id: dam.site_id,
      basin_id: dam.basin_id,
      site_id: dam.site_id,
      lat: parse(dam.metadata["Identificação"]["Latitude (m)"], "N"),
      lon: parse(dam.metadata["Identificação"]["Longitude (m)"], "W")
    }
  end

  def from_dam(dam) do
    %{
      id: dam.site_id,
      basin_id: dam.basin_id,
      site_id: dam.site_id,
      lat: parse(dam.metadata["Identificação"]["Latitude (m)"], "N"),
      lon: parse(dam.metadata["Identificação"]["Longitude (m)"], "W")
    }
  end

  def parse(coord, dir) do
    coord
    |> String.replace("º", "")
    |> String.replace("'", "")
    |> String.split(" ")
    |> then(fn [d, m, s] -> [String.to_integer(d), String.to_integer(m), Float.parse(s)] end)
    |> then(fn [d, m, {s, ""}] -> [d, m, s] end)
    |> then(fn [d, m, s] -> [abs(d), m, s] end)
    |> then(fn [d, m, s] -> %Geocalc.DMS{hours: d, minutes: m, seconds: s, direction: dir} end)
    |> Geocalc.DMS.to_decimal()
  end
end
