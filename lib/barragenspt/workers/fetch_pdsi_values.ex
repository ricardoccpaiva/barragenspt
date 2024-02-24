defmodule Barragenspt.Workers.FetchPdsiValues do
  use Oban.Worker, queue: :dams_info
  require Logger
  alias Barragenspt.Hydrometrics.PdsiValue
  import Ecto.Query
  alias Barragenspt.Parsers.SvgXmlParser

  def spawn_workers do
    from(_x in PdsiValue) |> Barragenspt.Repo.delete_all()

    combinations =
      for year <- 1981..2023,
          month <- 1..12,
          layer <- ["mpdsi.obsSup.monthly.vector.conc", "mpdsi.obsSup.monthly.vector.baciasHidro"],
          img_format <- [:svg],
          do: {year, month, layer, img_format}

    combinations
    |> Enum.map(fn {year, month, layer, img_format} ->
      build_worker(year, month, layer, img_format)
    end)
    |> Oban.insert_all()
  end

  defp build_worker(year, month, layer, img_format) do
    Barragenspt.Workers.FetchPdsiValues.new(%{
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
    |> SvgXmlParser.stream_parse_xml("pdsi")
    |> Stream.map(fn c -> build_struct(c, year, month, layer) end)
    |> Enum.each(fn m -> Barragenspt.Repo.insert!(m) end)

    :ok
  end

  defp fetch_image(year, month, _format, layer) do
    image_payload = Barragenspt.Services.Ipma.get_image(:pdsi, year, month, :svg, layer)

    path = "priv/static/images/pdsi/svg/monthly/#{year}_#{month}.svg"

    File.write!(path, image_payload)

    ExOptimizer.optimize(path)

    Logger.info("Successfully got PDSI image (svg format) for year #{month}/#{year}")

    path
  end

  defp build_struct(pdsi_value, year, month, "mpdsi.obsSup.monthly.vector.conc") do
    build_struct(pdsi_value, year, month, "municipalities")
  end

  defp build_struct(pdsi_value, year, month, "mpdsi.obsSup.monthly.vector.baciasHidro") do
    build_struct(pdsi_value, year, month, "basins")
  end

  defp build_struct(pdsi_value, year, month, geographic_area_type) do
    %PdsiValue{
      svg_path_hash: pdsi_value.svg_path_hash,
      color_hex: pdsi_value.color_hex,
      year: year,
      month: month,
      geographic_area_type: geographic_area_type
    }
  end
end
