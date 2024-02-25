defmodule Barragenspt.Workers.FetchPrecipitationMonthlyValues do
  use Oban.Worker, queue: :dams_info
  require Logger
  alias Barragenspt.Hydrometrics.PrecipitationMonthlyValue
  import Ecto.Query
  alias Barragenspt.Parsers.SvgXmlParser

  def spawn_workers do
    from(_x in PrecipitationMonthlyValue) |> Barragenspt.Repo.delete_all()

    combinations =
      for year <- 2000..2023,
          month <- 1..12,
          layer <- ["mrrto.obsSup.monthly.vector.conc"],
          img_format <- [:svg],
          do: {year, month, layer, img_format}

    combinations
    |> Enum.map(fn {year, month, layer, img_format} ->
      build_worker(year, month, layer, img_format)
    end)
    |> Oban.insert_all()
  end

  defp build_worker(year, month, layer, img_format) do
    Barragenspt.Workers.FetchPrecipitationMonthlyValues.new(%{
      "year" => year,
      "month" => month,
      "format" => img_format,
      "layer" => layer
    })
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"year" => year, "month" => month, "format" => "svg", "layer" => layer}
      }) do
    file_path = fetch_image(year, month, :svg, layer)

    file_path
    |> Path.expand()
    |> File.read!()
    |> SvgXmlParser.stream_parse_xml("precipitation")
    |> Stream.map(fn c -> build_struct(c, year, month) end)
    |> Enum.each(fn m -> Barragenspt.Repo.insert!(m) end)

    ExOptimizer.optimize(file_path)

    :ok
  end

  defp fetch_image(year, month, _format, layer) do
    image_payload = Barragenspt.Services.Ipma.get_image(:precipitation, year, month, :svg, layer)

    path = "priv/static/images/precipitation/svg/monthly/#{year}_#{month}.svg"

    File.write!(path, image_payload)

    Logger.info("Successfully got precipitation image (svg format) for year #{month}/#{year}")

    path
  end

  defp build_struct(pdsi_value, year, month) do
    %PrecipitationMonthlyValue{
      svg_path_hash: pdsi_value.svg_path_hash,
      color_hex: pdsi_value.color_hex,
      year: year,
      month: month,
      geographic_area_type: "municipalities"
    }
  end
end
