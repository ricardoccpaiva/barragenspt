defmodule BarragensptWeb.DamDataController do
  use BarragensptWeb, :controller
  alias Barragenspt.Geo.Coordinates
  alias Barragenspt.Hydrometrics.Dams
  alias Barragenspt.Mappers.Colors
  alias Barragenspt.Hydrometrics.Dams

  def show(conn, %{"site_id" => site_id, "period" => period}) do
    dam_data = get_data_for_period(site_id, period)

    render(conn, "show.json", dam_data: dam_data)
  end

  defp get_data_for_period(id, value) do
    case value do
      "y" <> val ->
        {int_value, ""} = Integer.parse(val)

        id
        |> Dams.discharge_monthly_stats(int_value)
        |> Enum.map(fn dd -> %{value: dd.value, date: dd.date, basin: "Descarga"} end)
        |> Kernel.++(Dams.monthly_stats(id, int_value))

      "m" <> val ->
        {int_value, ""} = Integer.parse(val)

        id
        |> Dams.discharge_stats(int_value, :month)
        |> Enum.map(fn dd -> %{value: dd.value, date: dd.date, basin: "Descarga"} end)
        |> Kernel.++(Dams.daily_stats(id, int_value))

      "s" <> val ->
        {int_value, ""} = Integer.parse(val)

        id
        |> Dams.discharge_stats(int_value, :week)
        |> Enum.map(fn dd -> %{value: dd.value, date: dd.date, basin: "Descarga"} end)
        |> Kernel.++(Dams.hourly_stats(id, int_value))
    end
  end
end
