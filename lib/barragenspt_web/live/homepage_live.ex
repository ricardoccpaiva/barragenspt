defmodule BarragensptWeb.HomepageLive do
  use BarragensptWeb, :live_view
  import Ecto.Query

  def mount(_params, _session, socket) do
    coords =
      from(Barragenspt.Hydrometrics.Dam)
      |> Barragenspt.Repo.all()
      |> Enum.map(fn dam -> build_coord(dam) end)
      |> Enum.map(fn dam -> Map.put(dam, :basin_color, lookup_color(dam.basin_id)) end)
      |> Enum.map(fn dam -> Map.put(dam, :pct, :rand.uniform(100)) end)
      |> Enum.map(fn dam ->
        Map.put(dam, :capacity_color, lookup_capacity_color(dam.pct))
      end)

    query =
      from p in Barragenspt.Hydrometrics.Dam,
        group_by: [p.basin_id, p.basin],
        select: %{basin: p.basin, id: p.basin_id}

    basins =
      query
      |> Barragenspt.Repo.all()
      |> Enum.map(fn basin -> Map.put(basin, :pct, :rand.uniform(100)) end)
      |> Enum.map(fn basin -> Map.put(basin, :pct_2, :rand.uniform(100)) end)
      |> Enum.map(fn basin -> Map.put(basin, :color, lookup_color(basin.id)) end)
      |> Enum.map(fn basin ->
        Map.put(basin, :capacity_color, lookup_capacity_color(basin.pct))
      end)

    {:ok, assign(socket, coords: coords, basins: basins)}
  end

  def handle_params(%{"id" => id}, _url, socket) do
    dam = Barragenspt.Repo.one(from p in Barragenspt.Hydrometrics.Dam, where: p.site_id == ^id)

    {:noreply, socket |> assign(dam: dam.name)}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket |> assign(stuff: "NADA", dam: "NADA")}
  end

  defp lookup_capacity_color(pct) do
    cond do
      0 < pct and pct <= 20 -> "#ce0808"
      21 <= pct and pct <= 40 -> "#f78c18"
      41 <= pct and pct <= 50 -> "#f7ef08"
      51 <= pct and pct <= 60 -> "#f7ef08"
      61 <= pct and pct <= 80 -> "#a5ef18"
      81 <= pct and pct <= 100 -> "#a5ef18"
      true -> "grey"
    end
  end

  defp lookup_color(basin_id) do
    mappings = [
      {992, "#F94144"},
      {68, "#F3722C"},
      {38, "#F8961E"},
      {138, "#F9844A"},
      {107, "#F9C74F"},
      {1_551_779_250, "#90BE6D"},
      {12, "#43AA8B"},
      {47, "#4D908E"},
      {17, "#577590"},
      {23, "#277DA1"},
      {1_551_779_242, "#ff006e"},
      {8, "#cbf3f0"}
    ]

    {_k, color} = Enum.find(mappings, fn {k, _v} -> k == basin_id end)

    color
  end

  defp build_coord(dam) do
    %{
      id: dam.site_id,
      basin_id: dam.basin_id,
      lat: to_decimal_coord(dam.metadata["Identificação"]["Latitude (m)"], "N"),
      lon: to_decimal_coord(dam.metadata["Identificação"]["Longitude (m)"], "W")
    }
  end

  defp to_decimal_coord(coord, dir) do
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
