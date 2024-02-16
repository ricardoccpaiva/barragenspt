defmodule Barragenspt.Workers.BuildPdsiWmsCache do
  use Oban.Worker, queue: :dams_info
  require Logger

  def spawn_workers do
    combinations =
      for year <- 2000..2023,
          month <- 1..12,
          layer <- ["mpdsi.obsSup.monthly.vector.conc", "mpdsi.obsSup.monthly.vector.baciasHidro"],
          img_format <- ["image%2Fpng"],
          do: {year, month, layer, img_format}

    combinations
    |> Enum.map(fn {year, month, layer, img_format} ->
      build_worker(year, month, layer, img_format)
    end)
    |> Oban.insert_all()
  end

  defp build_worker(year, month, layer, img_format) do
    Barragenspt.Workers.BuildPdsiWmsCache.new(%{
      "year" => year,
      "month" => month,
      "format" => img_format,
      "layer" => layer
    })
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"year" => year, "month" => month, "format" => format, "layer" => layer}
      }) do
    month =
      month
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    time = "#{year}-#{month}-01T00%3A00%3A00Z"

    query_params =
      "?service=WMS&request=GetMap&layers=#{layer}&styles=&format=#{format}&transparent=true&version=1.1.1&time=#{time}&srs=EPSG%3A3857&bbox={bbox-epsg-3857}&width=256&height=256"

    {:ok, _ret} = Barragenspt.Services.BarragensPtClient.get_wms_pdsi(query_params)
    :ok
  end
end
