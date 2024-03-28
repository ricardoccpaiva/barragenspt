defmodule Barragenspt.Workers.FetchPrecipitationMonthlyValues do
  use Oban.Worker, queue: :meteo_data
  require Logger
  alias Barragenspt.Hydrometrics.PrecipitationMonthlyValue
  import Ecto.Query
  alias Barragenspt.Parsers.SvgXmlParser
  alias Barragenspt.Services.R2
  import Mogrify

  def spawn_workers do
    from(_x in PrecipitationMonthlyValue) |> Barragenspt.Repo.delete_all()

    sd = Date.new!(2000, 1, 1)
    ed = Date.utc_today()
    dates = Date.range(sd, ed)
    dates = Enum.filter(dates, fn dt -> dt.day == 1 end)

    combinations =
      for date <- dates,
          layer <- ["mrrto.obsSup.monthly.vector.conc"],
          img_format <- [:svg],
          do: {date.year, date.month, layer, img_format}

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
        args: args = %{"year" => year, "month" => month, "format" => "svg", "layer" => layer}
      }) do
    query =
      from(pdv in PrecipitationMonthlyValue,
        where: pdv.year == ^year and pdv.month == ^month
      )

    Barragenspt.Repo.delete_all(query)

    {:ok, path} = Briefly.create(directory: true)

    file_path = Path.join(path, "#{UUID.uuid4()}.xls")

    {:ok, cache_status, file_payload} = fetch_image(year, month, layer)

    :ok = File.write!(file_path, file_payload)

    rows_created =
      file_path
      |> Path.expand()
      |> File.read!()
      |> SvgXmlParser.stream_parse_xml("precipitation", "monthly")
      |> Stream.map(fn c -> build_struct(c, year, month) end)
      |> Enum.map(fn m -> Barragenspt.Repo.insert!(m) end)

    if Enum.any?(rows_created) do
      if cache_status == :cache_miss do
        R2.upload(
          file_path,
          "/precipitation/svg/monthly/raw/#{year}_#{month}.svg"
        )

        # ExOptimizer.optimize(file_path)

        # R2.upload(
        # file_path,
        # "/precipitation/svg/monthly/minified/#{year}_#{month}.svg"
        # )
      end

      jpg_remote_path =
        "/precipitation/jpg/monthly/#{year}_#{month}.jpg"

      if(!R2.exists?(jpg_remote_path)) do
        jpg_local_file_path = Path.join(path, "#{UUID.uuid4()}.png")

        %Mogrify.Image{
          path: _path,
          ext: ".png",
          format: "jpeg",
          buffer: nil,
          operations: [],
          dirty: %{}
        } =
          file_path
          |> open
          |> format("jpeg")
          |> quality("100")
          |> resize_to_fill("202x387")
          |> save(path: jpg_local_file_path)

        R2.upload(jpg_local_file_path, jpg_remote_path)
      end
    else
      Logger.info("Precipitation information not available for #{inspect(args)}")
    end

    :ok
  end

  defp fetch_image(year, month, layer) do
    case R2.download("/precipitation/svg/monthly/raw/#{year}_#{month}.svg") do
      {:ok, payload} ->
        {:ok, :cache_hit, payload}

      {:error, :not_found} ->
        payload = get_from_ipma(year, month, layer)
        {:ok, :cache_miss, payload}
    end
  end

  defp get_from_ipma(year, month, layer) do
    payload = Barragenspt.Services.Ipma.get_image(:precipitation, year, month, :svg, layer)

    Logger.info(
      "Falling back download of /precipitation/svg/monthly/raw/#{year}_#{month}.svg from IPMA"
    )

    payload
  end

  defp build_struct(pdsi_value, year, month) do
    %PrecipitationMonthlyValue{
      svg_path_hash: pdsi_value.svg_path_hash,
      color_hex: pdsi_value.color_hex,
      year: year,
      month: month,
      geographic_area_type: "municipality"
    }
  end
end
