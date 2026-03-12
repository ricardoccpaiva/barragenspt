defmodule Barragenspt.Mappers.Colors do
  def lookup_capacity(%Decimal{} = pct) do
    pct |> Decimal.to_float() |> lookup_capacity()
  end

  # Escala alinhada com app.css (.legend-0-20 … .legend-81-100) e mapa
  def lookup_capacity(pct) do
    cond do
      pct <= 20 -> "#ff675c"
      pct <= 40 -> "#ffc34a"
      pct <= 50 -> "#ffe99c"
      pct <= 60 -> "#c2faaa"
      pct <= 80 -> "#a6d8ff"
      pct <= 100 -> "#1c9dff"
      true -> "#94a3b8"
    end
  end

  def lookup_index(pct) do
    cond do
      pct <= 20 -> 1
      pct <= 40 -> 2
      pct <= 50 -> 3
      pct <= 60 -> 4
      pct <= 80 -> 5
      pct <= 200 -> 6
      true -> 0
    end
  end

  def lookup(basin_id) when is_binary(basin_id) do
    {id, ""} = Integer.parse(basin_id)
    lookup(id)
  end

  def lookup(basin_id) do
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

    {_k, color} = Enum.find(mappings, {:ok, "#FFFFFF"}, fn {k, _v} -> k == basin_id end)

    color
  end
end
