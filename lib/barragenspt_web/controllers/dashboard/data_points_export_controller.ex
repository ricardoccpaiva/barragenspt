defmodule BarragensptWeb.Dashboard.DataPointsExportController do
  use BarragensptWeb, :controller

  alias Barragenspt.Hydrometrics.{Dams, DataPointParamLabels}
  alias Barragenspt.Models.Hydrometrics.DataPointWithDam

  def csv(conn, params) do
    case Dams.list_data_points_for_csv_export(params) do
      {:ok, rows} ->
        body = encode_csv(rows)
        filename = "pontos-dados-#{Date.utc_today()}.csv"

        conn
        |> put_resp_content_type("text/csv", "utf-8")
        |> put_resp_header("content-disposition", ~s[attachment; filename="#{filename}"])
        |> send_resp(200, "\uFEFF" <> body)

      {:error, :missing_param_name_filter} ->
        conn
        |> put_flash(
          :info,
          "Escolha um parâmetro em «Parâmetro», aplique os filtros e exporte de novo."
        )
        |> redirect(to: ~p"/dashboard/data-points")

      {:error, _} ->
        conn
        |> put_flash(:error, "Parâmetros de exportação inválidos.")
        |> redirect(to: ~p"/dashboard/data-points")
    end
  end

  @header ~w(dam_name basin parametro value colected_at)

  defp encode_csv(rows) do
    header_line = Enum.map_join(@header, ",", &csv_cell/1)

    lines =
      Enum.map(rows, fn %DataPointWithDam{} = row ->
        [
          row.dam_name,
          row.basin,
          DataPointParamLabels.label(row.param_name),
          row.value,
          row.colected_at
        ]
        |> Enum.map(&csv_cell/1)
        |> Enum.join(",")
      end)

    Enum.join([header_line | lines], "\r\n")
  end

  defp csv_cell(nil), do: ""

  defp csv_cell(%Decimal{} = d),
    do: d |> Decimal.round(4) |> Decimal.to_string(:normal) |> csv_cell()

  defp csv_cell(%NaiveDateTime{} = ndt),
    do: ndt |> NaiveDateTime.to_string() |> csv_cell()

  defp csv_cell(n) when is_integer(n), do: Integer.to_string(n)

  defp csv_cell(s) when is_binary(s) do
    if String.contains?(s, [",", "\"", "\n", "\r"]) do
      "\"" <> String.replace(s, "\"", "\"\"") <> "\""
    else
      s
    end
  end

  defp csv_cell(other), do: other |> to_string() |> csv_cell()
end
