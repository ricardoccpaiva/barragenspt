defmodule Barragenspt.Workers.FetchSvgAreas do
  use Oban.Worker, queue: :dams_info
  require Logger
  alias Barragenspt.Hydrometrics.SvgArea
  import Ecto.Query

  @impl Oban.Worker
  def perform(_args) do
    from(_x in SvgArea) |> Barragenspt.Repo.delete_all()

    "priv/static/svg/basins_pdsi.svg"
    |> Path.expand()
    |> File.read!()
    |> stream_parse_xml()
    |> stream_calculate_areas()
    |> Stream.map(fn a -> build_struct(a, "basin") end)
    |> Enum.each(fn a -> Barragenspt.Repo.insert!(a) end)

    "priv/static/svg/pt_map.svg"
    |> Path.expand()
    |> File.read!()
    |> stream_parse_xml()
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

  defp stream_parse_xml(xmldoc) do
    {doc, []} = xmldoc |> to_charlist() |> :xmerl_scan.string()

    paths_list = :xmerl_xpath.string(~c"/svg/g/path/@d", doc)

    Stream.map(paths_list, fn pl ->
      {:xmlAttribute, :d, [], [], [], [path: _p, g: _g, svg: _svg], _, [], path_str, false} = pl

      path_str
    end)
  end

  defp stream_calculate_areas(svg_paths) do
    Stream.map(svg_paths, fn svg_path -> %{svg_path: svg_path, area: calculate_area(svg_path)} end)
  end

  defp calculate_area(svg_path) do
    {pct, 0} = System.cmd("python3", ["svg_area.py", "#{svg_path}"])
    {decimal, ""} = pct |> String.replace("\n", "") |> Decimal.parse()

    decimal
  end
end