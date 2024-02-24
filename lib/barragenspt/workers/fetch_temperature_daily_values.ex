defmodule Barragenspt.Workers.FetchTemperatureDailyValues do
  use Oban.Worker, queue: :dams_info
  require Logger
  alias Barragenspt.Hydrometrics.TemperatureDailyValue
  import Ecto.Query
  alias Barragenspt.Parsers.SvgXmlParser

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
        where: pdv.date == ^dt
      )

    Barragenspt.Repo.delete_all(query)

    file_path = fetch_image(year, month, day, :svg, layer)

    file_path
    |> Path.expand()
    |> File.read!()
    |> SvgXmlParser.stream_parse_xml("temperature")
    |> Stream.map(fn c -> build_struct(c, year, month, day, layer) end)
    |> Enum.each(fn m -> Barragenspt.Repo.insert!(m) end)

    :timer.sleep(50)

    :ok
  end

  defp fetch_image(year, month, day, _format, layer) do
    image_payload =
      Barragenspt.Services.Ipma.get_image(:temperature, year, month, day, :svg, layer)

    path =
      "priv/static/images/temperature/svg/daily/#{year}_#{month}_#{day}_#{translate_layer(layer)}.svg"

    File.write!(path, image_payload)

    ExOptimizer.optimize(path)

    Logger.info("Successfully got temperature image (svg format) for #{day}/#{month}/#{year}")

    path
  end

  defp build_struct(pdsi_value, year, month, day, layer) do
    %TemperatureDailyValue{
      svg_path_hash: pdsi_value.svg_path_hash,
      color_hex: pdsi_value.color_hex,
      date: Date.new!(year, month, day),
      geographic_area_type: "municipalities",
      layer: translate_layer(layer)
    }
  end

  defp translate_layer("mtnmn.obsSup.daily.vector.conc"), do: "min"
  defp translate_layer("mtxmx.obsSup.daily.vector.conc"), do: "max"
end
