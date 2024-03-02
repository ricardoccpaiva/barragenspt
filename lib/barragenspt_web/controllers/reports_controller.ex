defmodule BarragensptWeb.ReportsController do
  use BarragensptWeb, :controller

  def index(
        conn,
        params = %{
          "meteo_index" => meteo_index,
          "viz_mode" => viz_mode,
          "viz_type" => viz_type,
          "time_frequency" => "monthly",
          "scale_type" => scale_type,
          "start" => dt_start,
          "end" => dt_end
        }
      ) do
    case parse_and_validate_date_range(dt_start, dt_end, meteo_index) do
      :ok ->
        map_urls =
          dt_start
          |> get_range(dt_end, meteo_index)
          |> Enum.group_by(fn r -> r.year end)
          |> Map.to_list()

        render(conn, :index,
          maps: map_urls,
          time_frequency: "monthly",
          meteo_index: meteo_index,
          viz_type: viz_type,
          viz_mode: viz_mode,
          dt_start: dt_start,
          scale_type: scale_type,
          dt_end: dt_end,
          errors: nil,
          correlate: Map.get(params, "correlate", "off"),
          title: build_title(meteo_index, "monthly", dt_start, dt_end)
        )

      {:error, :invalid_date_pdsi} ->
        render(conn, :index,
          maps: [],
          dt_start: dt_start,
          dt_end: dt_end,
          errors: ["A ano de início/fim não pode ser inferior a 1981."]
        )

      {:error, :invalid_date_precipitation} ->
        render(conn, :index,
          maps: [],
          dt_start: dt_start,
          dt_end: dt_end,
          errors: ["A ano de início/fim não pode ser inferior a 2000."]
        )

      {:error, :start_lt_end} ->
        render(conn, :index,
          maps: [],
          dt_start: dt_start,
          dt_end: dt_end,
          errors: ["A data de início não pode ser superior à data de fim."]
        )
    end
  end

  def index(
        conn,
        %{
          "meteo_index" => meteo_index,
          "viz_mode" => viz_mode,
          "viz_type" => viz_type,
          "time_frequency" => "daily",
          "start" => dt_start,
          "end" => dt_end
        }
      ) do
    meteo_index_parts = String.split(meteo_index, "_")
    meteo_index = List.last(meteo_index_parts)
    variant = List.first(meteo_index_parts)

    case parse_and_validate_date_range(dt_start, dt_end, meteo_index) do
      :ok ->
        map_urls =
          if viz_type == "chart" do
            DateHelper.generate_monthly_maps(dt_start, dt_end)
          else
            dt_start
            |> get_range(dt_end, meteo_index, variant)
            |> Enum.chunk_every(12)
          end

        render(conn, :index,
          maps: map_urls,
          time_frequency: "daily",
          meteo_index: meteo_index,
          viz_type: viz_type,
          viz_mode: viz_mode,
          dt_start: dt_start,
          dt_end: dt_end,
          errors: nil,
          title: build_title(meteo_index, "daily", dt_start, dt_end)
        )

      {:error, :period_too_long} ->
        render(conn, :index,
          maps: [],
          dt_start: dt_start,
          dt_end: dt_end,
          errors: ["O período máximo para análise diária é de 1 ano."]
        )

      {:error, :invalid_date_pdsi} ->
        render(conn, :index,
          maps: [],
          dt_start: dt_start,
          dt_end: dt_end,
          errors: ["A ano de início/fim não pode ser inferior a 1981."]
        )

      {:error, :invalid_date_precipitation} ->
        render(conn, :index,
          maps: [],
          dt_start: dt_start,
          dt_end: dt_end,
          errors: ["A ano de início/fim não pode ser inferior a 2000."]
        )

      {:error, :start_lt_end} ->
        render(conn, :index,
          maps: [],
          dt_start: dt_start,
          dt_end: dt_end,
          errors: ["A data de início não pode ser superior à data de fim."]
        )
    end
  end

  def index(conn, %{}) do
    render(conn, :index, maps: [], dt_start: nil, dt_end: nil, errors: nil)
  end

  defp build_title("temperature", "daily", dt_start, dt_end) do
    "Observação diária da temperatura 🌡️ entre #{dt_start} e #{dt_end}"
  end

  defp build_title("precipitation", "daily", dt_start, dt_end) do
    "Observação diária da precipitação acumulada 🌧️ entre #{dt_start} e #{dt_end}"
  end

  defp build_title("precipitation", "monthly", dt_start, dt_end) when dt_start == dt_end do
    "Observação mensal da precipitação acumulada 🌧️ em #{dt_start}"
  end

  defp build_title("precipitation", "monthly", dt_start, dt_end) do
    "Observação mensal da precipitação acumulada 🌧️ entre #{dt_start} e #{dt_end}"
  end

  defp build_title("pdsi", "monthly", dt_start, dt_end) when dt_start == dt_end do
    "Observação mensal do índice de seca (PDSI) 🌱 em #{dt_start}"
  end

  defp build_title("pdsi", "monthly", dt_start, dt_end) do
    "Observação mensal do índice de seca (PDSI) 🌱 entre #{dt_start} e #{dt_end}"
  end

  defp build_title("basin_storage", "monthly", dt_start, dt_end) do
    "Observação mensal da água armazenada 💦 entre #{dt_start} e #{dt_end}"
  end

  defp parse_and_validate_date_range(start_date, end_date, "temperature")
       when byte_size(start_date) == 7 and byte_size(end_date) == 7 do
    %{"day" => s_d, "month" => s_m, "year" => s_y} = parse_date(start_date)
    %{"day" => e_d, "month" => e_m, "year" => e_y} = parse_date(end_date)

    if String.to_integer(s_y) < 2000 || String.to_integer(e_y) < 2000 do
      {:error, :invalid_date_precipitation}
    else
      start_date =
        Date.new!(
          String.to_integer(s_y),
          String.to_integer(s_m),
          String.to_integer(s_d)
        )

      end_date =
        Date.new!(
          String.to_integer(e_y),
          String.to_integer(e_m),
          String.to_integer(e_d)
        )

      if Date.diff(end_date, start_date) > 365 do
        {:error, :period_too_long}
      else
        :ok
      end
    end
  end

  defp parse_and_validate_date_range(start_date, end_date, "precipitation")
       when byte_size(start_date) == 7 and byte_size(end_date) == 7 do
    %{"day" => s_d, "month" => s_m, "year" => s_y} = parse_date(start_date)
    %{"day" => e_d, "month" => e_m, "year" => e_y} = parse_date(end_date)

    if String.to_integer(s_y) < 2000 || String.to_integer(e_y) < 2000 do
      {:error, :invalid_date_precipitation}
    else
      start_date =
        Date.new!(
          String.to_integer(s_y),
          String.to_integer(s_m),
          String.to_integer(s_d)
        )

      end_date =
        Date.new!(
          String.to_integer(e_y),
          String.to_integer(e_m),
          String.to_integer(e_d)
        )

      if Date.diff(end_date, start_date) > 365 do
        {:error, :period_too_long}
      else
        :ok
      end
    end
  end

  defp parse_and_validate_date_range(start_date, end_date, "pdsi")
       when byte_size(start_date) == 7 and byte_size(end_date) == 7 do
    %{"day" => s_d, "month" => s_m, "year" => s_y} = parse_date(start_date)
    %{"day" => e_d, "month" => e_m, "year" => e_y} = parse_date(end_date)

    if String.to_integer(s_y) < 1981 || String.to_integer(e_y) < 1981 do
      {:error, :invalid_date_pdsi}
    else
      start_date =
        Date.new!(
          String.to_integer(s_y),
          String.to_integer(s_m),
          String.to_integer(s_d)
        )

      end_date =
        Date.new!(
          String.to_integer(e_y),
          String.to_integer(e_m),
          String.to_integer(e_d)
        )

      if end_date < start_date do
        {:error, :start_lt_end}
      else
        :ok
      end
    end
  end

  defp parse_and_validate_date_range(start_date, end_date, "precipitation")
       when byte_size(start_date) == 4 and byte_size(end_date) == 4 do
    if String.to_integer(start_date) < 2000 || String.to_integer(end_date) < 2000 do
      {:error, :invalid_date_precipitation}
    else
      if String.to_integer(start_date) > String.to_integer(end_date) do
        {:error, :start_lt_end}
      else
        :ok
      end
    end
  end

  defp parse_and_validate_date_range(start_date, end_date, "pdsi")
       when byte_size(start_date) == 4 and byte_size(end_date) == 4 do
    if String.to_integer(start_date) > String.to_integer(end_date) do
      {:error, :start_lt_end}
    else
      :ok
    end
  end

  defp parse_and_validate_date_range(start_date, end_date, "basin_storage")
       when byte_size(start_date) == 4 and byte_size(end_date) == 4 do
    if String.to_integer(start_date) > String.to_integer(end_date) do
      {:error, :start_lt_end}
    else
      :ok
    end
  end

  defp get_range(start_date, end_date, meteo_index)
       when byte_size(start_date) == 4 and byte_size(end_date) == 4 do
    for year <- String.to_integer(start_date)..String.to_integer(end_date),
        month <- 1..12,
        do: build_map_struct(year, month, meteo_index)
  end

  defp get_range(start_date, end_date, meteo_index, variant \\ nil)
       when byte_size(start_date) == 7 and byte_size(end_date) == 7 do
    start_date
    |> get_range(end_date)
    |> Enum.map(fn d -> build_map_struct(d, meteo_index, variant) end)
  end

  defp get_range(start_date, end_date) do
    %{"day" => s_d, "month" => s_m, "year" => s_y} = parse_date(start_date)
    %{"day" => e_d, "month" => e_m, "year" => e_y} = parse_date(end_date, :end_date)

    start_date =
      Date.new!(
        String.to_integer(s_y),
        String.to_integer(s_m),
        String.to_integer(s_d)
      )

    end_date =
      Date.new!(
        String.to_integer(e_y),
        String.to_integer(e_m),
        String.to_integer(e_d)
      )

    Date.range(start_date, end_date)
  end

  defp parse_date(date) do
    ~r/^(?'month'\d{2})\/(?'year'\d{4})$/
    |> Regex.named_captures(date)
    |> Map.put("day", "1")
  end

  defp parse_date(date, :end_date) do
    date =
      %{"month" => m, "year" => y} =
      Regex.named_captures(~r/^(?'month'\d{2})\/(?'year'\d{4})$/, date)

    d = Date.days_in_month(Date.new!(String.to_integer(y), String.to_integer(m), 1))

    Map.put(date, "day", "#{d}")
  end

  defp build_map_struct(year, month, meteo_index) when is_integer(year) and is_integer(month) do
    month_name = DateHelper.get_month_name({year, month, 1})
    abbreviated_year = String.slice("#{year}", -2, 2)

    %{
      url: "images/#{meteo_index}/svg/monthly/#{year}_#{month}.svg",
      date: "#{month_name} '#{abbreviated_year}",
      year: year
    }
  end

  defp build_map_struct(date, meteo_index, variant) do
    date = Date.to_string(date)
    regex = ~r/^(?'year'\d{4})-(?'month'\d{2})-(?'day'\d{2})$/
    %{"day" => d, "month" => m, "year" => y} = Regex.named_captures(regex, date)

    mx = String.replace(m, "0", "")
    dx = String.replace(d, "0", "")

    url =
      if variant in ["min", "max"] do
        "images/#{meteo_index}/svg/daily/#{y}_#{mx}_#{dx}_#{variant}.svg"
      else
        "images/#{meteo_index}/svg/daily/#{y}_#{mx}_#{dx}.svg"
      end

    %{
      url: url,
      date: "#{d}/#{m}/#{y}",
      year: y
    }
  end
end
