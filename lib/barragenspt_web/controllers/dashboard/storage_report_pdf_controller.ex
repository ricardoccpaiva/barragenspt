defmodule BarragensptWeb.Dashboard.StorageReportPdfController do
  use BarragensptWeb, :controller

  alias Barragenspt.Activity
  alias BarragensptWeb.Dashboard.StorageReportPresenter

  def show(conn, params) do
    selected = StorageReportPresenter.params_from_request(params)

    report =
      StorageReportPresenter.build_report(
        selected.report_type,
        selected.selected_basin,
        selected.selected_date,
        selected.selected_month
      )

    html =
      Phoenix.View.render_to_string(
        BarragensptWeb.Dashboard.StorageReportPdfView,
        "show.html",
        report: report,
        report_type: selected.report_type,
        selected_basin: selected.selected_basin
      )

    filename = StorageReportPresenter.filename(selected.report_type, report)

    case pdf_renderer().render(html) do
      {:ok, pdf} ->
        track_pdf_export(conn, selected, report)

        conn
        |> put_resp_content_type("application/pdf")
        |> put_resp_header("content-disposition", ~s[attachment; filename="#{filename}"])
        |> send_resp(200, pdf)

      {:error, reason} ->
        conn
        |> put_flash(:error, "Não foi possível gerar o PDF: #{inspect(reason)}")
        |> redirect(
          to:
            StorageReportPresenter.storage_report_path(
              selected.report_type,
              selected.selected_basin,
              selected.selected_date,
              selected.selected_month
            )
        )
    end
  end

  defp pdf_renderer do
    Application.get_env(:barragenspt, :pdf_renderer, BarragensptWeb.PdfRenderer.ChromicPDF)
  end

  defp track_pdf_export(conn, selected, report) do
    user_id = get_in(conn.assigns, [:current_scope, Access.key(:user), Access.key(:id)])

    metadata = %{
      "report_type" => selected.report_type,
      "selected_basin" => selected.selected_basin,
      "basin_count" => length(Map.get(report, :basins, []))
    }

    _ = Activity.record_event(user_id, Activity.report_pdf_exported_event(), metadata)
  end
end
