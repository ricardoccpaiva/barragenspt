defmodule Barragenspt.Workers.FetchSvgAreas do
  use Oban.Worker, queue: :meteo_data
  require Logger
  alias Barragenspt.Hydrometrics.SvgArea
  import Ecto.Query

  @impl Oban.Worker
  def perform(_args) do
    from(_x in SvgArea) |> Barragenspt.Repo.delete_all()

    "resources/svg/basins_pdsi.svg"
    |> Path.expand()
    |> File.read!()
    |> stream_parse_xml(~c"/svg/g/path/@d")
    |> stream_calculate_areas()
    |> Stream.map(fn a -> build_struct(a, "basin") end)
    |> Enum.each(fn a -> Barragenspt.Repo.insert!(a) end)

    "resources/svg/pt_map.svg"
    |> Path.expand()
    |> File.read!()
    |> stream_parse_xml(~c"/svg/g/path/@d")
    |> stream_calculate_areas()
    |> Stream.map(fn a -> build_struct(a, "municipality") end)
    |> Enum.each(fn a -> Barragenspt.Repo.insert!(a) end)

    :ok
  end

  defp build_struct(svg_area, geographic_area_type) do
    %SvgArea{
      svg_path: to_string(svg_area.svg_path),
      svg_path_hash: :crypto.hash(:md5, to_string(svg_area.svg_path)) |> Base.encode16(),
      area: svg_area.area,
      geographic_area_type: geographic_area_type
    }
  end

  defp stream_parse_xml(xmldoc, xpath) do
    {doc, []} = xmldoc |> to_charlist() |> :xmerl_scan.string()

    :xmerl_xpath.string(xpath, doc)
  end

  defp extract_path(
         {:xmlAttribute, :d, [], [], [], [path: _p, svg: _g], _svg, [], path_str, false}
       ) do
    path_str
  end

  defp extract_path(
         {:xmlAttribute, :d, [], [], [], [path: _p, g: _g, svg: _svg], _, [], path_str, false}
       ) do
    path_str
  end

  defp stream_calculate_areas(svg_paths) do
    Stream.map(svg_paths, fn svg_path ->
      svg_path = extract_path(svg_path)
      %{svg_path: svg_path, area: calculate_area(svg_path)}
    end)
  end

  defp calculate_area(svg_path) do
    {pct, 0} = System.cmd("python3", ["resources/svg/svg_area.py", "#{svg_path}"])
    {decimal, ""} = pct |> String.replace("\n", "") |> Decimal.parse()

    decimal
  end
end
