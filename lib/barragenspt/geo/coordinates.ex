defmodule Barragenspt.Geo.Coordinates do
  alias Barragenspt.Hydrometrics.Dams

  def bounding_box(site_id) do
    path = "priv/static/geojson/reservoirs/#{site_id}.geojson"

    if File.exists?(path) do
      path
      |> File.read!()
      |> Jason.decode!()
      |> Map.get("features")
      |> Enum.at(0)
      |> Map.get("geometry")
      |> Map.get("coordinates")
      |> Enum.at(0)
      |> Enum.to_list()
      |> Geocalc.bounding_box_for_points()
    else
      %{lat: lat, lon: lon} = from_dam(site_id)
      Geocalc.bounding_box([lon, lat], 10)
    end
  end

  def from_dam(id) when is_binary(id) do
    dam = Dams.get(id)

    %{
      lat: parse(dam.metadata["Identificação"]["Latitude (m)"], "N"),
      lon: parse(dam.metadata["Identificação"]["Longitude (m)"], "W")
    }
  end

  def from_dam(dam) do
    %{
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
