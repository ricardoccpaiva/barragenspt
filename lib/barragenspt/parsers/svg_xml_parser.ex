defmodule Barragenspt.Parsers.SvgXmlParser do
  alias Barragenspt.Converters.ColorConverter

  def stream_parse_xml(xmldoc, meteo_index) do
    {doc, []} = xmldoc |> to_charlist() |> :xmerl_scan.string()

    paths_list = :xmerl_xpath.string(~c"/svg/path", doc)

    Stream.map(paths_list, fn pl ->
      %{path: path, style: style} = extract_path_and_style(pl)

      hash =
        :md5
        |> :crypto.hash(to_string(path))
        |> Base.encode16()

      hex = convert_svg_color(to_string(style), meteo_index)

      %{svg_path_hash: hash, color_hex: hex}
    end)
  end

  defp extract_path_and_style(pl) do
    {:xmlElement, :path, :path, [], {:xmlNamespace, _, []}, [svg: _], _,
     [
       {:xmlAttribute, :d, [], [], [], [path: _, svg: _], _, [], path, _},
       {:xmlAttribute, :style, [], [], [], [path: _, svg: _], _, [], style, _}
     ], [], [], _, _} = pl

    %{path: path, style: style}
  end

  defp convert_svg_color(input, meteo_index) do
    # Extract RGB percentages from the input string
    regex = ~r/fill:rgb\((\d+(\.\d+)?%)\s*,\s*(\d+(\.\d+)?%)\s*,\s*(\d+(\.\d+)?%)\);/

    {red, green, blue} =
      case Regex.run(regex, input) do
        ["fill:rgb(0%,0%,0%);", "0%", "", "0%", "", "0%"] ->
          {"0.0%", "0.0%", "0.0%"}

        ["fill:rgb(100%,100%,100%);", _red, "", _green, "", _blue] ->
          {"100.0%", "100.0%", "100.0%"}

        [_ignore1, red, _ignore2, green, _ignore3, blue] ->
          {red, green, blue}

        [_ignore1, red, _ignore2, green, _ignore3, blue, _ignore4] ->
          {red, green, blue}

        ["fill:rgb(0%,0%,0%);", "0%", "", "0%", "", "0%"] ->
          {"0%", "0%", "0%"}

        ["fill:rgb(100%,100%,100%);", _red, "", _green, "", _blue] ->
          {"100.0%", "100.0%", "100.0%"}

        [_ignore1, red, _ignore2, green, _ignore3, blue, _ignore4] ->
          {red, green, blue}
      end

    ColorConverter.get_hex_color(
      meteo_index,
      "rgb(#{red},#{green},#{blue})"
    )
  end
end
