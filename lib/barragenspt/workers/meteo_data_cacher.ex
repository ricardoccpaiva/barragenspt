defmodule Barragenspt.Workers.MeteoDataCacher do
  use Oban.Worker, queue: :stats_cacher

  def spawn_workers() do
    Barragenspt.Cache.flush()

    combinations =
      for year <- 2000..2023,
          month <- 1..12,
          layer <- ["min", "max"],
          do: {year, month, layer}

    jobs =
      Enum.map(combinations, fn {year, month, layer} ->
        Barragenspt.Workers.MeteoDataCacher.new(%{
          "year" => year,
          "month" => month,
          "layer" => layer
        })
      end)

    Oban.insert_all(jobs)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"year" => year, "month" => month, "layer" => layer}}) do
    Barragenspt.Meteo.Temperature.get_temperature_data_by_scale(year, month, layer)
    Barragenspt.Meteo.Pdsi.get_pdsi_data_by_scale(year)
    :ok
  end
end
