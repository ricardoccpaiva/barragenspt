defmodule Barragenspt.Workers.FetchPrecipitationDailyValues do
  use Oban.Worker, queue: :dams_info
  require Logger
  alias Barragenspt.Hydrometrics.PrecipitationDailyValue
  import Ecto.Query

  def spawn_workers do
    from(_x in PrecipitationDailyValue) |> Barragenspt.Repo.delete_all()

    combinations =
      for year <- 2000..2023,
          month <- 1..12,
          layer <- ["mrrto.obsSup.daily.vector.conc"],
          img_format <- [:svg],
          do: {year, month, layer, img_format}

    Enum.each(combinations, fn {year, month, layer, img_format} ->
      jobs = build_worker(year, month, layer, img_format)

      Oban.insert_all(jobs)
    end)
  end

  defp build_worker(year, month, layer, img_format) do
    {:ok, dt} = Date.new(year, month, 1)

    for day <- 1..Date.days_in_month(dt),
        do:
          Barragenspt.Workers.FetchPrecipitationDailyValues.new(%{
            "year" => year,
            "month" => month,
            "day" => day,
            "format" => img_format,
            "layer" => layer
          })
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "year" => year,
          "month" => month,
          "day" => day,
          "format" => "svg",
          "layer" => layer
        }
      }) do
    dt = Date.new!(year, month, day)

    query =
      from(pdv in PrecipitationDailyValue,
        where: pdv.date == ^dt
      )

    Barragenspt.Repo.delete_all(query)

    file_path = fetch_image(year, month, day, :svg, layer)

    file_path
    |> Path.expand()
    |> File.read!()
    |> stream_parse_xml()
    |> Stream.map(fn c -> build_struct(c, year, month, day) end)
    |> Enum.each(fn m -> Barragenspt.Repo.insert!(m) end)

    :timer.sleep(200)

    :ok
  end

  defp fetch_image(year, month, day, _format, layer) do
    image_payload =
      Barragenspt.Services.Ipma.get_image(:precipitation, year, month, day, :svg, layer)

    path =
      "priv/static/images/precipitation/svg/daily/#{year}_#{month}_#{day}.svg"

    File.write!(path, image_payload)

    Logger.info("Successfully got precipitation image (svg format) for #{day}/#{month}/#{year}")

    path
  end

  defp stream_parse_xml(xmldoc) do
    {doc, []} = xmldoc |> to_charlist() |> :xmerl_scan.string()

    paths_list = :xmerl_xpath.string(~c"/svg/g/path", doc)

    Stream.map(paths_list, fn pl ->
      %{path: path, style: style} = extract_path_and_style(pl)

      hash =
        :md5
        |> :crypto.hash(to_string(path))
        |> Base.encode16()

      hex = convert_svg_color(to_string(style))

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

  defp convert_svg_color(input) do
    # Extract RGB percentages from the input string
    regex = ~r/fill:rgb\((\d+(\.\d+)?%)\s*,\s*(\d+(\.\d+)?%)\s*,\s*(\d+(\.\d+)?%)\);/

    {red, green, blue} =
      case Regex.run(regex, input) do
        ["fill:rgb(0%,0%,0%);", "0%", "", "0%", "", "0%"] -> {"0%", "0%", "0%"}
        ["fill:rgb(100%,100%,100%);", red, "", green, "", blue] -> {red, green, blue}
        [_ignore1, red, _ignore2, green, _ignore3, blue, _ignore4] -> {red, green, blue}
      end

    # Convert RGB percentages to hexadecimal
    rgb_to_hex(parse_float(red), parse_float(green), parse_float(blue))
  end

  defp parse_float(float) do
    float
    |> String.replace("%", "")
    |> Float.parse()
    |> then(fn {float, ""} -> float end)
  end

  defp rgb_to_hex(red_percent, green_percent, blue_percent) do
    # Convert percentage to integer value (0-255)
    red = round(red_percent * 255 / 100)
    green = round(green_percent * 255 / 100)
    blue = round(blue_percent * 255 / 100)

    # Convert integer values to hexadecimal
    hex =
      Integer.to_string(red, 16) <> Integer.to_string(green, 16) <> Integer.to_string(blue, 16)

    # Ensure the hexadecimal string has two characters for each color
    String.pad_leading(hex, 6, "0")
  end

  defp build_struct(pdsi_value, year, month, day) do
    %PrecipitationDailyValue{
      svg_path_hash: pdsi_value.svg_path_hash,
      color_hex: pdsi_value.color_hex,
      date: Date.new!(year, month, day),
      geographic_area_type: "municipalities"
    }
  end
end
