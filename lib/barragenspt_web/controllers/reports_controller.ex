defmodule BarragensptWeb.ReportsController do
  use BarragensptWeb, :controller

  def index(
        conn,
        %{
          "meteo_index" => meteo_index,
          "viz_mode" => _viz_mode,
          "time_frequency" => "monthly",
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
          dt_start: dt_start,
          dt_end: dt_end,
          errors: nil,
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
          "viz_mode" => _viz_mode,
          "time_frequency" => "daily",
          "start" => dt_start,
          "end" => dt_end
        }
      ) do
    case parse_and_validate_date_range(dt_start, dt_end, meteo_index) do
      :ok ->
        map_urls =
          dt_start
          |> get_range(dt_end, meteo_index)
          |> Enum.chunk_every(12)

        render(conn, :index,
          maps: map_urls,
          time_frequency: "daily",
          meteo_index: meteo_index,
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

  defp parse_and_validate_date_range(start_date, end_date, _meteo_index)
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

  defp get_range(start_date, end_date, meteo_index)
       when byte_size(start_date) == 7 and byte_size(end_date) == 7 do
    start_date
    |> get_range(end_date)
    |> Enum.map(fn d -> build_map_struct(d, meteo_index) end)
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

  defp build_map_struct(year, month, meteo_index) do
    month_name = DateHelper.get_month_name({year, month, 1})
    abbreviated_year = String.slice("#{year}", -2, 2)

    %{
      url: "images/#{meteo_index}/svg/monthly/#{year}_#{month}.svg",
      date: "#{month_name} '#{abbreviated_year}",
      year: year
    }
  end

  defp build_map_struct(date, meteo_index) do
    date = Date.to_string(date)
    regex = ~r/^(?'year'\d{4})-(?'month'\d{2})-(?'day'\d{2})$/
    %{"day" => d, "month" => m, "year" => y} = Regex.named_captures(regex, date)

    mx = String.replace(m, "0", "")
    dx = String.replace(d, "0", "")

    %{
      url: "images/#{meteo_index}/svg/daily/#{y}_#{mx}_#{dx}.svg",
      date: "#{d}/#{m}/#{y}",
      year: y
    }
  end
end

defmodule DateHelper do
  @months ~w(Jan Fev Mar Abr Mai Jun Jul Ago Set Out Nov Dez)a

  def get_month_name({_year, month, _day}) do
    Enum.at(@months, month - 1)
  end
end
