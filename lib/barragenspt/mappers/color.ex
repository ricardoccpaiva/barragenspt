defmodule Barragenspt.Mappers.Colors do
  def lookup_capacity(%Decimal{} = pct) do
    pct |> Decimal.to_float() |> lookup_capacity()
  end

  def lookup_capacity(pct) do
    cond do
      0 < pct and pct < 21 -> "#FFADAD"
      21 <= pct and pct <= 41 -> "#FFD6A5"
      41 <= pct and pct <= 51 -> "#FDFFB6"
      51 <= pct and pct <= 61 -> "#CAFFBF"
      61 <= pct and pct <= 81 -> "#A6D8FF"
      81 <= pct and pct <= 100 -> "#72B6F9"
      true -> "#D3D3D3"
    end
  end

  def lookup_index(pct) do
    cond do
      0 < pct and pct < 21 -> 1
      21 <= pct and pct <= 41 -> 2
      41 <= pct and pct <= 51 -> 3
      51 <= pct and pct <= 61 -> 4
      61 <= pct and pct <= 81 -> 5
      81 <= pct and pct <= 100 -> 6
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
