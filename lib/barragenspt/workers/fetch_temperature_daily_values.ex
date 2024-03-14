defmodule Barragenspt.Workers.FetchTemperatureDailyValues do
  use Oban.Worker, queue: :dams_info
  require Logger
  alias Barragenspt.Hydrometrics.TemperatureDailyValue
  import Ecto.Query
  alias Barragenspt.Parsers.SvgXmlParser
  alias Barragenspt.Services.R2

  def spawn_workers do
    from(_x in TemperatureDailyValue) |> Barragenspt.Repo.delete_all()

    sd = Date.new!(2000, 1, 1)
    ed = Date.utc_today()
    dates = Date.range(sd, ed)
    dates = Enum.filter(dates, fn dt -> dt.day == 1 end)

    combinations =
      for date <- dates,
          layer <- ["mtnmn.obsSup.daily.vector.conc", "mtxmx.obsSup.daily.vector.conc"],
          img_format <- [:svg],
          do: {date.year, date.month, layer, img_format}

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
        args:
          args = %{
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

    {:ok, cache_status, file_payload} = fetch_image(year, month, day, layer)

    :ok = File.write!(file_path, file_payload)

    rows_created =
      file_path
      |> Path.expand()
      |> File.read!()
      |> SvgXmlParser.stream_parse_xml("temperature")
      |> Stream.map(fn c -> build_struct(c, year, month, day, layer) end)
      |> Enum.map(fn m -> Barragenspt.Repo.insert!(m) end)

    if Enum.any?(rows_created) do
      if cache_status == :cache_miss do
        R2.upload(
          file_path,
          "/temperature/svg/daily/raw/#{year}_#{month}_#{day}_#{translate_layer(layer)}.svg"
        )

        ExOptimizer.optimize(file_path)

        R2.upload(
          file_path,
          "/temperature/svg/daily/minified/#{year}_#{month}_#{day}_#{translate_layer(layer)}.svg"
        )
      end
    else
      Logger.info("Temperature information not available for #{inspect(args)}")
    end

    :ok
  end

  defp fetch_image(year, month, day, layer) do
    remote_path =
      "/temperature/svg/daily/raw/#{year}_#{month}_#{day}_#{translate_layer(layer)}.svg"

    case R2.download(remote_path) do
      {:ok, payload} ->
        {:ok, :cache_hit, payload}

      {:error, :not_found} ->
        payload = get_from_ipma(year, month, day, layer)
        {:ok, :cache_miss, payload}
    end
  end

  defp get_from_ipma(year, month, day, layer) do
    payload = Barragenspt.Services.Ipma.get_image(:temperature, year, month, day, :svg, layer)

    Logger.info(
      "Falling back download of for  /temperature/svg/daily/raw/#{year}_#{month}_#{day}_#{translate_layer(layer)}.svg from IPMA"
    )

    payload
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
