defmodule BarragensptWeb.PdfRenderer.ChromicPDF do
  @moduledoc false

  def render(html, opts \\ []) do
    pdf_opts =
      Keyword.merge(
        [
          print_to_pdf: %{
            printBackground: true,
            preferCSSPageSize: true,
            marginTop: 0,
            marginRight: 0,
            marginBottom: 0,
            marginLeft: 0
          }
        ],
        opts
      )

    case ChromicPDF.print_to_pdf({:html, html}, pdf_opts) do
      {:ok, blob} -> Base.decode64(IO.iodata_to_binary(blob))
      other -> other
    end
  end
end
