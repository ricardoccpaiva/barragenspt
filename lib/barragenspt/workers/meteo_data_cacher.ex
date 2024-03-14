defmodule Barragenspt.Workers.MeteoDataCacher do
  use Oban.Worker, queue: :stats_cacher

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"jcid" => _jcid}}) do
    spawn_workers()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "year" => year,
          "month" => month,
          "layer" => layer,
          "meteo_index" => "temperature"
        }
      }) do
    Barragenspt.Meteo.Temperature.get_data_by_scale(year, month, layer)
    :ok
  end

  def perform(%Oban.Job{
        args: %{"year" => year, "month" => month, "meteo_index" => "precipitation"}
      }) do
    Barragenspt.Meteo.Precipitation.get_precipitation_data(year, month)
    :ok
  end

  def perform(%Oban.Job{
        args: %{"year" => year, "meteo_index" => "precipitation"}
      }) do
    Barragenspt.Meteo.Precipitation.get_monthly_precipitation_data_by_scale(year)
    Barragenspt.Meteo.Precipitation.get_precipitation_data(year)
    :ok
  end

  def perform(%Oban.Job{
        args: %{"year" => year, "meteo_index" => "pdsi"}
      }) do
    Barragenspt.Meteo.Pdsi.get_pdsi_data_by_scale(year)
    :ok
  end

  defp spawn_workers() do
    Barragenspt.Cache.flush()

    sd = Date.new!(2000, 1, 1)
    ed = Date.utc_today()
    dates = Date.range(sd, ed)
    dates = Enum.filter(dates, fn dt -> dt.day == 1 end)

    combinations =
      for date <- dates,
          layer <- ["min", "max"],
          do: {date.year, date.month, layer}

    combinations_precipitation =
      for date <- dates,
          do: {date.year, date.month}

    jobs =
      Enum.map(combinations, fn {year, month, layer} ->
        Barragenspt.Workers.MeteoDataCacher.new(%{
          "year" => year,
          "month" => month,
          "layer" => layer,
          "meteo_index" => "temperature"
        })
      end)

    Oban.insert_all(jobs)

    years = Enum.uniq(combinations_precipitation, fn {year, _month} -> year end)

    jobs =
      Enum.map(years, fn {year, _month} ->
        Barragenspt.Workers.MeteoDataCacher.new(%{
          "year" => year,
          "meteo_index" => "pdsi"
        })
      end)

    Oban.insert_all(jobs)

    jobs =
      Enum.map(years, fn {year, _month} ->
        Barragenspt.Workers.MeteoDataCacher.new(%{
          "year" => year,
          "meteo_index" => "precipitation"
        })
      end)

    Oban.insert_all(jobs)

    jobs =
      Enum.map(combinations_precipitation, fn {year, month} ->
        Barragenspt.Workers.MeteoDataCacher.new(%{
          "year" => year,
          "month" => month,
          "meteo_index" => "precipitation"
        })
      end)

    Oban.insert_all(jobs)
  end
end
