defmodule BarragensptWeb.ReportsController do
  use BarragensptWeb, :controller

  @meteo_index_limits_mapping [
    %{meteo_index: "temperature", limits: %{min: 2000, max: 2024}},
    %{meteo_index: "precipitation", limits: %{min: 2000, max: 2024}},
    %{meteo_index: "pdsi", limits: %{min: 1981, max: 2024}},
    %{meteo_index: "basin_storage", limits: %{min: 1981, max: 2024}}
  ]

  @error_types_mapping [
    %{
      error_type: :invalid_min_date,
      error_message: "A ano de início não pode ser inferior a"
    },
    %{
      error_type: :invalid_max_date,
      error_message: "A ano de fim não pode ser inferior a"
    },
    %{
      error_type: :start_lt_end,
      error_message: "A data de início não pode ser superior à data de fim."
    },
    %{
      error_type: :daily_analysis_period_too_long,
      error_message: "O período máximo para análise diária é de 1 ano."
    },
    %{
      error_type: :monthly_analysis_period_too_long,
      error_message: "O período máximo para análise mensal é de 10 anos."
    }
  ]

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
    case parse_and_validate_date_range(dt_start, dt_end, meteo_index, :monthly) do
      {:ok, dates: %{start_date: start_date, end_date: end_date}} ->
        map_urls =
          get_range(start_date, end_date, meteo_index, :monthly)
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

      {:error, error_type} ->
        error_message = build_error_message(error_type, meteo_index)

        render(conn, :index,
          maps: [],
          dt_start: dt_start,
          dt_end: dt_end,
          errors: [error_message]
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

    case parse_and_validate_date_range(dt_start, dt_end, meteo_index, :daily) do
      {:ok, dates: %{start_date: start_date, end_date: end_date}} ->
        map_urls =
          if viz_type == "chart" do
            DateHelper.generate_monthly_maps(dt_start, dt_end)
          else
            range = get_range(start_date, end_date, meteo_index, :daily, variant)

            Enum.chunk_every(range, 12)
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

      {:error, error_type} ->
        error_message = build_error_message(error_type, meteo_index)

        render(conn, :index,
          maps: [],
          dt_start: dt_start,
          dt_end: dt_end,
          errors: [error_message]
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

  defp parse_and_validate_date_range(start_date, end_date, meteo_index, time_frequency) do
    start_date = parse_date(start_date)
    end_date = parse_date(end_date, time_frequency == :monthly)

    case validate_date_limits(start_date, end_date, meteo_index, time_frequency) do
      :ok -> {:ok, dates: %{start_date: start_date, end_date: end_date}}
      error -> error
    end
  end

  defp validate_date_limits(start_date, end_date, meteo_index, time_frequency) do
    %{limits: %{min: min, max: max}} =
      Enum.find(@meteo_index_limits_mapping, fn m -> m.meteo_index == meteo_index end)

    if start_date.year < min || end_date.year < min do
      {:error, :invalid_min_date}
    else
      if start_date.year > max || end_date.year > max do
        {:error, :invalid_max_date}
      else
        if end_date < start_date do
          {:error, :start_lt_end}
        else
          if time_frequency == :daily && Date.diff(end_date, start_date) > 365 do
            {:error, :daily_analysis_period_too_long}
          else
            if time_frequency == :monthly && end_date.year - start_date.year > 10 do
              {:error, :monthly_analysis_period_too_long}
            else
              :ok
            end
          end
        end
      end
    end
  end

  defp get_range(start_date, end_date, meteo_index, time_frequency) do
    range = Date.range(start_date, end_date)

    range
    |> Enum.reject(fn r -> r.day > 1 && time_frequency == :monthly end)
    |> Enum.map(fn r -> build_map_struct(r.year, r.month, meteo_index) end)
  end

  defp get_range(start_date, end_date, meteo_index, _time_frequency, variant) do
    range = Date.range(start_date, end_date)

    Enum.map(range, fn r -> build_map_struct(r, meteo_index, variant) end)
  end

  defp parse_date(date, is_end_date \\ false) do
    regex_year_month = ~r/^(?'month'\d{2})\/(?'year'\d{4})$/
    regex_year = ~r/^(?'year'\d{4})$/

    if(Regex.match?(regex_year_month, date)) do
      %{"month" => m, "year" => y} = Regex.named_captures(regex_year_month, date)

      y = String.to_integer(y)
      m = String.to_integer(m)

      Date.new!(y, m, 1)
    else
      if Regex.match?(regex_year, date) do
        %{"year" => y} = Regex.named_captures(regex_year, date)

        y = String.to_integer(y)

        if is_end_date do
          Date.new!(y, 12, 31)
        else
          Date.new!(y, 1, 1)
        end
      else
        {:error, :invalid_date}
      end
    end
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

  defp build_error_message(error_type, meteo_index) do
    %{limits: %{min: min, max: _max}} =
      Enum.find(@meteo_index_limits_mapping, fn m -> m.meteo_index == meteo_index end)

    %{error_message: error_message} =
      Enum.find(@error_types_mapping, fn m -> m.error_type == error_type end)

    error_message_sufix =
      case error_type do
        :invalid_min_date -> " #{min}."
        :invalid_max_date -> " #{min}."
        _ -> ""
      end

    "#{error_message}#{error_message_sufix}"
  end
end
