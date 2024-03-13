defmodule Barragenspt.Workers.FetchTemperatureDailyValues do
  use Oban.Worker, queue: :dams_info
  require Logger
  alias Barragenspt.Hydrometrics.TemperatureDailyValue
  import Ecto.Query
  alias Barragenspt.Parsers.SvgXmlParser
  alias Barragenspt.Services.S3

  def spawn_workers do
    from(_x in TemperatureDailyValue) |> Barragenspt.Repo.delete_all()

    combinations =
      for year <- 2000..2023,
          month <- 1..12,
          layer <- ["mtnmn.obsSup.daily.vector.conc", "mtxmx.obsSup.daily.vector.conc"],
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
          Barragenspt.Workers.FetchTemperatureDailyValues.new(%{
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
      from(pdv in TemperatureDailyValue,
        where: pdv.date == ^dt and pdv.layer == ^layer
      )

    Barragenspt.Repo.delete_all(query)

    {:ok, path} = Briefly.create(directory: true)

    file_path = Path.join(path, "#{UUID.uuid4()}.xls")

    file_payload = fetch_image(year, month, day, :svg, layer)

    :ok = File.write!(file_path, file_payload)

    file_path
    |> Path.expand()
    |> File.read!()
    |> SvgXmlParser.stream_parse_xml("temperature")
    |> Stream.map(fn c -> build_struct(c, year, month, day, layer) end)
    |> Enum.each(fn m -> Barragenspt.Repo.insert!(m) end)

    S3.upload(
      file_path,
      "assets-barragens-pt",
      "/temperature/svg/daily/raw/#{year}_#{month}_#{day}_#{translate_layer(layer)}.svg"
    )

    ExOptimizer.optimize(file_path)

    S3.upload(
      file_path,
      "assets-barragens-pt",
      "/temperature/svg/daily/minified/#{year}_#{month}_#{day}_#{translate_layer(layer)}.svg"
    )

    :ok
  end

  defp fetch_image(year, month, day, _format, layer) do
    image_payload =
      Barragenspt.Services.Ipma.get_image(:temperature, year, month, day, :svg, layer)

    Logger.info("Successfully got temperature image (svg format) for #{day}/#{month}/#{year}")

    image_payload
  end

  defp build_struct(pdsi_value, year, month, day, layer) do
    %TemperatureDailyValue{
      svg_path_hash: pdsi_value.svg_path_hash,
      color_hex: pdsi_value.color_hex,
      date: Date.new!(year, month, day),
      geographic_area_type: "municipality",
      layer: translate_layer(layer)
    }
  end

  defp translate_layer("mtnmn.obsSup.daily.vector.conc"), do: "min"
  defp translate_layer("mtxmx.obsSup.daily.vector.conc"), do: "max"
end
