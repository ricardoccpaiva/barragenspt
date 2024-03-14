defmodule Barragenspt.Workers.FetchPdsiValues do
  use Oban.Worker, queue: :dams_info
  require Logger
  alias Barragenspt.Hydrometrics.PdsiValue
  import Ecto.Query
  alias Barragenspt.Parsers.SvgXmlParser
  alias Barragenspt.Services.R2

  def spawn_workers do
    from(_x in PdsiValue) |> Barragenspt.Repo.delete_all()

    sd = Date.new!(1981, 1, 1)
    ed = Date.utc_today()
    dates = Date.range(sd, ed)
    dates = Enum.filter(dates, fn dt -> dt.day == 1 end)

    combinations =
      for date <- dates,
          layer <- ["mpdsi.obsSup.monthly.vector.conc", "mpdsi.obsSup.monthly.vector.baciasHidro"],
          img_format <- [:svg],
          do: {date.year, date.month, layer, img_format}

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
        args: args = %{"year" => year, "month" => month, "format" => "svg", "layer" => layer}
      }) do
    {:ok, path} = Briefly.create(directory: true)

    file_path = Path.join(path, "#{UUID.uuid4()}.xls")

    {:ok, cache_status, file_payload} = fetch_image(year, month, :svg, layer)
    :ok = File.write!(file_path, file_payload)

    rows_created =
      file_path
      |> Path.expand()
      |> File.read!()
      |> SvgXmlParser.stream_parse_xml("pdsi")
      |> Stream.map(fn c -> build_struct(c, year, month, layer) end)
      |> Enum.map(fn m -> Barragenspt.Repo.insert!(m) end)

    if Enum.any?(rows_created) do
      if cache_status == :cache_miss do
        R2.upload(
          file_path,
          "/pdsi/svg/monthly/raw/#{year}_#{month}.svg"
        )

        ExOptimizer.optimize(file_path)

        R2.upload(
          file_path,
          "/pdsi/svg/monthly/minified/#{year}_#{month}.svg"
        )
      end
    else
      Logger.info("PDSI information not available for #{inspect(args)}")
    end

    :ok
  end

  defp fetch_image(year, month, _format, layer) do
    case R2.download("/pdsi/svg/monthly/raw/#{year}_#{month}.svg") do
      {:ok, payload} ->
        {:ok, :cache_hit, payload}

      {:error, :not_found} ->
        payload = get_from_ipma(year, month, layer)
        {:ok, :cache_miss, payload}
    end
  end

  def get_from_ipma(year, month, layer) do
    payload = Barragenspt.Services.Ipma.get_image(:pdsi, year, month, :svg, layer)

    Logger.info("Falling back download of /pdsi/svg/monthly/raw/#{year}_#{month}.svg from IPMA")

    payload
  end

  defp build_struct(pdsi_value, year, month, "mpdsi.obsSup.monthly.vector.conc") do
    build_struct(pdsi_value, year, month, "municipality")
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
