defmodule Barragenspt.Workers.RefreshPrecipitationMonthlyValues do
  use Oban.Worker, queue: :meteo_data
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{}}) do
    layer = "mrrto.obsSup.monthly.vector.conc"
    beginning_of_current_month = Date.beginning_of_month(Date.utc_today())

    beginning_of_3_months_before = Timex.shift(beginning_of_current_month, months: -3)

    dt_range = Date.range(beginning_of_3_months_before, beginning_of_current_month)

    dt_range
    |> Enum.reject(fn dt -> dt.day != 1 end)
    |> Enum.map(fn dt -> build_worker(dt.year, dt.month, layer, :svg) end)
    |> OpentelemetryOban.insert_all()

    :ok
  end

  defp build_worker(year, month, layer, img_format) do
    Barragenspt.Workers.FetchPrecipitationMonthlyValues.new(%{
      "year" => year,
      "month" => month,
      "format" => img_format,
      "layer" => layer
    })
  end
end
