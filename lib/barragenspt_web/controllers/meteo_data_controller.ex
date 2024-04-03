defmodule BarragensptWeb.MeteoDataController do
  use BarragensptWeb, :controller
  use Nebulex.Caching
  alias Barragenspt.MeteoDataCache, as: Cache
  alias Barragenspt.Meteo.Temperature
  alias Barragenspt.Meteo.Precipitation
  alias Barragenspt.Meteo.Pdsi
  alias Barragenspt.Hydrometrics.Basins

  @daily_scale [
    %{color_hex: "#360e38", index: 0},
    %{color_hex: "#88218c", index: 1},
    %{color_hex: "#753d8d", index: 2},
    %{color_hex: "#685e98", index: 3},
    %{color_hex: "#6a74a4", index: 4},
    %{color_hex: "#788db4", index: 5},
    %{color_hex: "#8da4c4", index: 6},
    %{color_hex: "#aec5dc", index: 7},
    %{color_hex: "#e0ecf4", index: 8},
    %{color_hex: "000000", index: -1}
  ]

  @monthly_scale [
    %{index: 1, color_hex: "#000000"},
    %{index: 2, color_hex: "#fde0dd"},
    %{index: 3, color_hex: "#fcc5c0"},
    %{index: 4, color_hex: "#fa9fb5"},
    %{index: 5, color_hex: "#f768a1"},
    %{index: 6, color_hex: "#de3497"},
    %{index: 7, color_hex: "#ae027e"},
    %{index: 8, color_hex: "#7a0277"},
    %{index: 9, color_hex: "#753d8d"},
    %{index: 10, color_hex: "#685e98"},
    %{index: 11, color_hex: "#6a74a4"},
    %{index: 12, color_hex: "#788db4"},
    %{index: 13, color_hex: "#8da4c4"},
    %{index: 14, color_hex: "#aec5dc"},
    %{index: 15, color_hex: "#e0ecf4"},
    %{index: 16, color_hex: "#f7fcfd"},
    %{index: 17, color_hex: "#ffffff"}
  ]

  def index(
        conn,
        args = %{
          "year" => year,
          "month" => month,
          "meteo_index" => "precipitation"
        }
      ) do
    year = String.to_integer(year)
    month = String.to_integer(month)
    compare = Map.get(args, "compare_with_ref", "off")

    data =
      if month == 0 do
        raw_data = Precipitation.get_monthly_precipitation_data_by_scale(year)

        raw_ref_data =
          if compare == "on",
            do: Precipitation.get_reference_monthly_precipitation(),
            else: nil

        build_precipitation_csv(raw_data, year, month, @monthly_scale, raw_ref_data)
      else
        raw_data = Precipitation.get_precipitation_data(year, month)
        build_precipitation_csv(raw_data, year, month, @daily_scale)
      end

    conn
    |> put_resp_content_type("text/csv")
    |> send_resp(200, data)
  end

  def index(conn, %{"year" => year, "meteo_index" => "basin_storage"}) do
    data =
      year
      |> String.to_integer()
      |> Basins.yearly_stats_for_basin()
      |> build_basin_storage_csv(year)

    conn
    |> put_resp_content_type("text/csv")
    |> send_resp(200, data)
  end

  def index(conn, %{"year" => year, "meteo_index" => "precipitation"}) do
    data =
      year
      |> String.to_integer()
      |> Precipitation.get_precipitation_data()
      |> backfill_precipitation_data()
      |> build_precipitation_csv(year, 0, @daily_scale)

    conn
    |> put_resp_content_type("text/csv")
    |> send_resp(200, data)
  end

  def index(conn, %{
        "start_date" => start_date,
        "end_date" => end_date,
        "meteo_index" => "precipitation"
      }) do
    start_date = start_date |> Timex.parse!("{D}/{0M}/{YYYY}") |> Timex.to_date()
    end_date = end_date |> Timex.parse!("{D}/{0M}/{YYYY}") |> Timex.to_date()

    data =
      start_date
      |> Precipitation.get_bounded_precipitation_data(end_date)
      |> build_precipitation_csv(@daily_scale)

    conn
    |> put_resp_content_type("text/csv")
    |> send_resp(200, data)
  end

  def index(conn, %{"year" => year, "month" => month, "meteo_index" => meto_index}) do
    year = String.to_integer(year)
    month = String.to_integer(month)

    meteo_index_layer =
      meto_index
      |> String.split("_")
      |> List.first()

    raw_data = Temperature.get_data_by_scale(year, month, meteo_index_layer)
    data = build_temperature_csv(raw_data, year, month, meteo_index_layer)

    conn
    |> put_resp_content_type("text/csv")
    |> send_resp(200, data)
  end

  def index(conn, %{"year" => year, "meteo_index" => "pdsi"}) do
    year = String.to_integer(year)

    raw_data = Pdsi.get_pdsi_data_by_scale(year)
    data = build_pdsi_csv(raw_data, year)

    conn
    |> put_resp_content_type("text/csv")
    |> send_resp(200, data)
  end

  @decorate cacheable(
              cache: Cache,
              key: "build_basin_storage_csv_#{year}",
              ttl: 9_999_999
            )
  defp build_basin_storage_csv(data, year) do
    header = "basin,date,value"

    data
    |> Enum.map(fn d -> "#{d.basin},#{d.date},#{d.value}" end)
    |> Enum.join("\n")
    |> Kernel.then(fn v -> "#{header}\n#{v}" end)
  end

  @decorate cacheable(
              cache: Cache,
              key: "temperature_csv_data_#{year}_#{month}_#{layer}",
              ttl: 999
            )
  defp build_temperature_csv(data, year, month, layer) do
    colors_index = [
      %{color_hex: "#49006a", index: 0},
      %{color_hex: "#ae027e", index: 1},
      %{color_hex: "#df7df8", index: 2},
      %{color_hex: "#e5c0f6", index: 3},
      %{color_hex: "#ccebc5", index: 4},
      %{color_hex: "#a8ddb5", index: 5},
      %{color_hex: "#7bccc4", index: 6},
      %{color_hex: "#4fb3d2", index: 7},
      %{color_hex: "#2b8cbf", index: 8},
      %{color_hex: "#559b97", index: 9},
      %{color_hex: "#6fa97c", index: 10},
      %{color_hex: "#96b85f", index: 11},
      %{color_hex: "#b0c24f", index: 12},
      %{color_hex: "#cacc3c", index: 13},
      %{color_hex: "#e3d627", index: 14},
      %{color_hex: "#ffdd04", index: 15},
      %{color_hex: "#ffaa01", index: 16},
      %{color_hex: "#ff8e00", index: 17},
      %{color_hex: "#ff7002", index: 18},
      %{color_hex: "#ff3901", index: 19},
      %{color_hex: "#e63000", index: 20},
      %{color_hex: "#cd2700", index: 21},
      %{color_hex: "#b41c00", index: 22},
      %{color_hex: "#9c1400", index: 23},
      %{color_hex: "#6a0000", index: 24}
    ]

    header = "date,color_hex,value,index"

    data
    |> Enum.map(fn d ->
      index =
        colors_index
        |> Enum.find(fn c -> c.color_hex == d.color_hex end)
        |> Map.get(:index)

      "#{d.date},#{d.color_hex},#{d.weight},#{index}"
    end)
    |> Enum.join("\n")
    |> Kernel.then(fn v -> "#{header}\n#{v}" end)
  end

  @decorate cacheable(
              cache: Cache,
              key:
                "precipitation_csv_data_#{year}_#{month}_#{:erlang.phash2(color_scale)}_#{:erlang.phash2(ref_data)}",
              ttl: 999
            )
  defp build_precipitation_csv(data, year, month, color_scale, ref_data \\ nil) do
    header = "date,color_hex,value,index,type"

    data
    |> Enum.map(fn d ->
      if !Map.has_key?(d, :date) do
        dt = Date.new!(d.year, d.month, 1)
        Map.put(d, :date, dt)
      else
        d
      end
    end)
    |> Enum.map(fn d ->
      index =
        color_scale
        |> Enum.find(fn c -> c.color_hex == d.color_hex end)
        |> Map.get(:index)

      x = "#{d.date},#{d.color_hex},#{d.value},#{index},observed"

      if ref_data do
        rd = Enum.find(ref_data, fn rd -> rd.month == d.date.month end)

        new_x = "#{d.date},#C1E1C1,#{rd.value},17,historic"
        [x, new_x]
      else
        [x]
      end
    end)
    |> List.flatten()
    |> Enum.join("\n")
    |> Kernel.then(fn v -> "#{header}\n#{v}" end)
  end

  @decorate cacheable(
              cache: Cache,
              key:
                "precipitation_csv_data_#{:erlang.phash2(data)}_#{:erlang.phash2(color_scale)}",
              ttl: 9_999_999
            )
  defp build_precipitation_csv(data, color_scale) do
    header = "date,color_hex,value,index"

    data
    |> Enum.map(fn d ->
      if !Map.has_key?(d, :date) do
        dt = Date.new!(d.year, d.month, 1)
        Map.put(d, :date, dt)
      else
        d
      end
    end)
    |> Enum.map(fn d ->
      index =
        color_scale
        |> Enum.find(fn c -> c.color_hex == d.color_hex end)
        |> Map.get(:index)

      "#{d.date},#{d.color_hex},#{d.value},#{index}"
    end)
    |> List.flatten()
    |> Enum.join("\n")
    |> Kernel.then(fn v -> "#{header}\n#{v}" end)
  end

  @decorate cacheable(
              cache: Cache,
              key: "pdsi_csv_data_#{year}",
              ttl: 99_999_999
            )
  defp build_pdsi_csv(data, year) do
    colors_index = [
      %{index: 0, color: "#9c551f"},
      %{index: 1, color: "#b5773e"},
      %{index: 2, color: "#cfa263"},
      %{index: 3, color: "#e8cf90"},
      %{index: 4, color: "#e9ffbe"},
      %{index: 5, color: "#c7deb4"},
      %{index: 6, color: "#91bda8"},
      %{index: 7, color: "#5c9e9c"},
      %{index: 8, color: "#218291"}
    ]

    header = "date,color_hex,value,index"

    data
    |> Enum.map(fn d ->
      if !Map.has_key?(d, :date) do
        dt = Date.new!(d.year, d.month, 1)
        Map.put(d, :date, dt)
      else
        d
      end
    end)
    |> Enum.map(fn d ->
      index =
        colors_index
        |> Enum.find(fn c -> c.color == d.color_hex end)
        |> Map.get(:index)

      "#{d.date},#{d.color_hex},#{d.weight},#{index}"
    end)
    |> Enum.join("\n")
    |> Kernel.then(fn v -> "#{header}\n#{v}" end)
  end

  defp backfill_precipitation_data(data) do
    latest = Enum.max_by(data, & &1.date)
    end_date = Date.new!(latest.date.year, 12, 31)

    if Date.diff(latest.date, end_date) == 0 do
      data
    else
      dates = Date.range(latest.date, end_date)

      values =
        Enum.map(dates, fn dt ->
          %{
            color_hex: "#e0ecf4",
            date: dt,
            value: Decimal.new("0.00")
          }
        end)

      values ++ data
    end
  end
end
