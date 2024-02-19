defmodule BarragensptWeb.MeteoDataController do
  use BarragensptWeb, :controller
  use Nebulex.Caching
  use Nebulex.Caching
  alias Barragenspt.Cache
  alias Barragenspt.Hydrometrics.SvgArea
  alias Barragenspt.Hydrometrics.PrecipitationDailyValue
  alias Barragenspt.Hydrometrics.PrecipitationLegendMapping
  import Ecto.Query

  def index(conn, %{"year" => year}) do
    parts = String.split(year, ".")
    {year, ""} = Integer.parse(List.first(parts))

    data =
      year
      |> get_precipitation_data()
      |> build_csv(year)

    conn
    |> put_resp_content_type("text/csv")
    |> send_resp(200, data)
  end

  @decorate cacheable(
              cache: Cache,
              key: "precipitation_csv_data_#{year}",
              ttl: 99_999_999
            )
  defp build_csv(data, year) do
    data
    |> Enum.map(fn d -> "#{d.date},#{d.weighted_average}" end)
    |> Enum.join("\n")
    |> Kernel.then(fn v -> "date,value\n#{v}" end)
  end

  @decorate cacheable(
              cache: Cache,
              key: "precipitation_data_#{year}",
              ttl: 99_999_999
            )
  def get_precipitation_data(year) do
    subquery =
      from pdv in PrecipitationDailyValue,
        join: sa in SvgArea,
        on: pdv.svg_path_hash == sa.svg_path_hash,
        join: plm in PrecipitationLegendMapping,
        on: pdv.color_hex == plm.color_hex,
        group_by: [pdv.date, pdv.color_hex, plm.mean_value],
        order_by: [asc: pdv.date],
        select: %{
          count: count(1),
          date: pdv.date,
          color_hex: pdv.color_hex,
          mean_value: plm.mean_value,
          weight: sum(sa.area) / 60541.204940844229249
        }

    query =
      from(c in subquery(subquery),
        group_by: c.date,
        where: fragment("EXTRACT(year FROM ?) = ?", c.date, ^year),
        select: %{
          date: c.date,
          weighted_average: sum(c.mean_value * c.weight) / sum(c.weight)
        }
      )

    Barragenspt.Repo.all(query)
  end
end
