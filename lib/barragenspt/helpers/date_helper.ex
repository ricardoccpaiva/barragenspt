defmodule DateHelper do
  @months ~w(Jan Fev Mar Abr Mai Jun Jul Ago Set Out Nov Dez)a

  def get_month_name({_year, month, _day}) do
    Enum.at(@months, month - 1)
  end

  def parse_date(date_str) do
    [month_str, year_str] = String.split(date_str, "/")
    {String.to_integer(month_str), String.to_integer(year_str)}
  end

  def generate_monthly_maps(start_date_str, end_date_str) do
    {start_month, start_year} = parse_date(start_date_str)
    {end_month, end_year} = parse_date(end_date_str)

    Enum.flat_map(start_year..end_year, fn year ->
      months =
        case year do
          ^start_year -> Enum.slice(1..12, start_month - 1, 12 - start_month + 1)
          ^end_year -> Enum.slice(1..12, 0, end_month)
          _ -> 1..12
        end

      Enum.map(months, fn month -> %{year: year, month: month} end)
    end)
  end
end
