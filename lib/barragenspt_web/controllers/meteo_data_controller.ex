defmodule BarragensptWeb.MeteoDataController do
  use BarragensptWeb, :controller
  use Nebulex.Caching
  alias Barragenspt.Cache
  alias Barragenspt.Meteo.Temperature
  alias Barragenspt.Meteo.Precipitation
  alias Barragenspt.Meteo.Pdsi

  def index(
        conn,
        args = %{
          "year" => year,
          "scale" => scale,
          "grouped" => "true",
          "meteo_index" => "precipitation"
        }
      ) do
    year = String.to_integer(year)
    scale = String.to_atom(scale)
    month = args |> Map.get("month", "0") |> String.to_integer()

    raw_data =
      if month == 0 do
        Precipitation.get_precipitation_data_by_scale(year, scale)
      else
        Precipitation.get_precipitation_data_by_scale(year, month, scale)
      end

    data = build_precipitation_csv(raw_data, year, month, scale)

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

  def index(conn, %{"year" => year, "meteo_index" => "precipitation"}) do
    year = String.to_integer(year)

    raw_data = Precipitation.get_precipitation_data(year)
    data = build_csv(raw_data, year)

    conn
    |> put_resp_content_type("text/csv")
    |> send_resp(200, data)
  end

  defp build_csv(data, year) do
    data
    |> Enum.map(fn d -> "#{d.date},#{d.weighted_average}" end)
    |> Enum.join("\n")
    |> Kernel.then(fn v -> "date,value\n#{v}" end)
  end

  @decorate cacheable(
              cache: Cache,
              key: "temperature_csv_data_#{year}_#{month}_#{layer}",
              ttl: 999
            )
  def build_temperature_csv(data, year, month, layer) do
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
              key: "precipitation_csv_data_#{year}_#{month}_#{variant}",
              ttl: 999
            )
  def build_precipitation_csv(data, year, month \\ 0, variant) do
    colors_index =
      if month != 0 do
        [
          %{color_hex: "#360e38", index: 0},
          %{color_hex: "#88218c", index: 1},
          %{color_hex: "#753d8d", index: 2},
          %{color_hex: "#685e98", index: 3},
          %{color_hex: "#6a74a4", index: 4},
          %{color_hex: "#788db4", index: 5},
          %{color_hex: "#8da4c4", index: 6},
          %{color_hex: "#aec5dc", index: 7},
          %{color_hex: "#e0ecf4", index: 8}
        ]
      else
        [
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
      end

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
        |> Enum.find(fn c -> c.color_hex == d.color_hex end)
        |> Map.get(:index)

      "#{d.date},#{d.color_hex},#{d.value},#{index}"
    end)
    |> Enum.join("\n")
    |> Kernel.then(fn v -> "#{header}\n#{v}" end)
  end

  @decorate cacheable(
              cache: Cache,
              key: "pdsi_csv_data_#{year}",
              ttl: 99_999_999
            )
  def build_pdsi_csv(data, year) do
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
end
