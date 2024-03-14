defmodule Barragenspt.Parsers.SvgXmlParser do
  alias Barragenspt.Converters.ColorConverter

  def stream_parse_xml(xmldoc, meteo_index, variant \\ nil) do
    {doc, []} = xmldoc |> to_charlist() |> :xmerl_scan.string()

    paths_list = :xmerl_xpath.string(~c"/svg/g/path", doc)

    Stream.map(paths_list, fn pl ->
      %{path: path, style: style} = extract_path_and_style(pl)

      hash =
        :md5
        |> :crypto.hash(to_string(path))
        |> Base.encode16()

      hex = convert_svg_color(to_string(style), meteo_index, variant)

      %{svg_path_hash: hash, color_hex: hex}
    end)
  end

  defp extract_path_and_style(pl) do
    {:xmlElement, :path, :path, [],
     {:xmlNamespace, :"http://www.w3.org/2000/svg",
      [{~c"xlink", :"http://www.w3.org/1999/xlink"}]}, [g: _g, svg: _svg], _n1,
     [
       {:xmlAttribute, :style, [], [], [], [path: _p1, g: _g1, svg: _svg1], _n2, [], style,
        false},
       {:xmlAttribute, :d, [], [], [], [path: _p2, g: _g2, svg: _svg2], _n3, [], path, false}
     ], [], [], _path, _ignore} = pl

    %{path: path, style: style}
  end

  defp convert_svg_color(input, meteo_index, variant) do
    # Extract RGB percentages from the input string
    regex = ~r/fill:rgb\((\d+(\.\d+)?%)\s*,\s*(\d+(\.\d+)?%)\s*,\s*(\d+(\.\d+)?%)\);/

    {red, green, blue} =
      case Regex.run(regex, input) do
        [_ignore1, red, _ignore2, green, _ignore3, blue] ->
          {red, green, blue}

        [_ignore1, red, _ignore2, green, _ignore3, blue, _ignore4] ->
          {red, green, blue}

        ["fill:rgb(0%,0%,0%);", "0%", "", "0%", "", "0%"] ->
          {"0%", "0%", "0%"}

        ["fill:rgb(100%,100%,100%);", _red, "", _green, "", _blue] ->
          {"100%", "100%", "100%"}

        [_ignore1, red, _ignore2, green, _ignore3, blue, _ignore4] ->
          {red, green, blue}
      end

    ColorConverter.get_hex_color(
      meteo_index,
      "rgb(#{red},#{green},#{blue})",
      variant
    )
  end
end
