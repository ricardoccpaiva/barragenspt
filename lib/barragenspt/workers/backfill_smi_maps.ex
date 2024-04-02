defmodule Barragenspt.Workers.BackfillSmiMaps do
  use Oban.Worker, queue: :meteo_data
  require Logger
  alias Barragenspt.Services.R2

  def spawn_workers do
    sd = Date.new!(2017, 10, 1)
    ed = Date.utc_today()
    dates = Date.range(sd, ed)

    combinations =
      for date <- dates,
          layer <- ["smi.obsRem.daily.grid.continental.timeDimension"],
          img_format <- [:png],
          do: {date.year, date.month, date.day, layer, img_format}

    combinations
    |> Enum.map(fn {year, month, day, layer, img_format} ->
      build_worker(year, month, day, layer, img_format)
    end)
    |> Oban.insert_all()
  end

  defp build_worker(year, month, day, layer, img_format) do
    Barragenspt.Workers.BackfillSmiMaps.new(%{
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
            "format" => "png",
            "layer" => layer
          }
      }) do
    {:ok, path} = Briefly.create(directory: true)

    file_path = Path.join(path, "#{UUID.uuid4()}.png")

    {:ok, cache_status, file_payload} = fetch_image(year, month, day, :png, layer)
    :ok = File.write!(file_path, file_payload)

    if cache_status == :cache_miss do
      try do
        %{animated: false, format: "png", frame_count: 1, height: 774, width: 404} =
          Mogrify.identify(file_path)

        R2.upload(
          file_path,
          "/smi/png/daily/#{year}_#{month}_#{day}.png"
        )
      rescue
        _e in MatchError ->
          Logger.info("Invalid PNG file: /smi/png/daily/#{year}_#{month}_#{day}.png")
          false
      end
    end

    :ok
  end

  defp fetch_image(year, month, day, _format, layer) do
    case R2.download("/smi/png/daily/#{year}_#{month}_#{day}.png") do
      {:ok, payload} ->
        {:ok, :cache_hit, payload}

      {:error, :not_found} ->
        payload = get_from_ipma(year, month, day, layer)
        {:ok, :cache_miss, payload}
    end
  end

  def get_from_ipma(year, month, day, layer) do
    payload = Barragenspt.Services.Ipma.get_image(:smi, year, month, day, :png, layer)

    Logger.info("Falling back download of /smi/png/daily/#{year}_#{month}_#{day}.png from IPMA")

    payload
  end
end
