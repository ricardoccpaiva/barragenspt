defmodule Mix.Tasks.ReservoirOsmDownload do
  @moduledoc "The hello mix task: `mix help hello`"
  use Mix.Task

  def run(_) do
    Application.ensure_all_started(:hackney)

    "resources/reservoirs_osm.csv"
    |> File.stream!()
    |> NimbleCSV.RFC4180.parse_stream()
    |> Stream.map(fn [site_id, dam_name, urls] ->
      process(site_id, dam_name, urls)
    end)
    |> Stream.run()

    :ok
  end

  defp process(site_id, _dam_name, urls) do
    url_list =
      urls
      |> String.trim_leading()
      |> String.split(";")
      |> Enum.reject(fn u -> u == "" end)

    download_file(site_id, url_list)
  end

  defp download_file(site_id, [head | _tail = []]) do
    %HTTPoison.Response{body: body} = HTTPoison.get!("#{head}/full", [], [])

    path = "priv/static/geojson/reservoirs/#{site_id}"

    save_and_convert(path, body)
  end

  defp download_file(site_id, [_head | _tail] = urls) do
    Enum.with_index(urls, fn url, index ->
      %HTTPoison.Response{body: body} = HTTPoison.get!("#{url}/full", [], [])

      path = "priv/static/geojson/reservoirs/#{site_id}_index_#{index}"

      save_and_convert(path, body)
    end)
  end

  defp download_file(_site_id, []) do
    :noop
  end

  defp save_and_convert(path, content) do
    osm_file_path = "#{path}.osm"

    :ok = File.write(osm_file_path, content)

    System.cmd("osmtogeojson", ["#{Path.absname(path)}.osm"],
      into: File.stream!("#{Path.absname(path)}.geojson")
    )

    File.rm(osm_file_path)
  end
end
