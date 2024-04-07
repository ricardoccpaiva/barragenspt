defmodule Barragenspt.Workers.RefreshPrecipitationDailyValues do
  use Oban.Worker, queue: :meteo_data
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{}}) do
    layers = ["mrrto.obsSup.daily.vector.conc"]
    current_date = Date.utc_today()
    one_week_before = Timex.shift(current_date, days: -7)

    dates = Date.range(one_week_before, current_date)

    combinations =
      for date <- dates,
          layer <- layers,
          do: {date.year, date.month, date.day, layer, :svg}

    combinations
    |> Enum.map(fn {year, month, day, layer, img_format} ->
      build_worker(year, month, day, layer, img_format)
    end)
    |> OpentelemetryOban.insert_all()

    :ok
  end

  defp build_worker(year, month, day, layer, img_format) do
    Barragenspt.Workers.FetchPrecipitationDailyValues.new(%{
      "year" => year,
      "month" => month,
      "day" => day,
      "format" => img_format,
      "layer" => layer
    })
  end
end
