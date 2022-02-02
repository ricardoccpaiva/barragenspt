defmodule Barragenspt.Workers.FetchDamSiteIds do
  use Oban.Worker, queue: :dams_info

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => _id} = _args}) do
    get_raw_html()
    |> Floki.parse_document!()
    |> Floki.find("#dbasepesquisador_tbllistaresultados")
    |> hd()
    |> then(fn {"table", _first, rows} -> rows end)
    |> tl()
    |> Stream.filter(fn row -> is_row_to_update?(row) end)
    |> Stream.map(fn {"tr", [], [_item1, item2 | _rest]} -> parse_row(item2) end)
    |> Stream.each(fn {dam_code, site_id} -> update_dam(dam_code, site_id) end)
    |> Stream.run()

    :ok
  end

  defp is_row_to_update?({"tr", [], [_item1, _item2 | _rest]}), do: true
  defp is_row_to_update?(_), do: false

  defp get_raw_html() do
    payload =
      "accao=go&tipo_entrada=0&form_estacao=&form_rede%5B1%5D=920123705&f_divisao_administrativa=&f_curso_agua="

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    %HTTPoison.Response{body: body, status_code: 200} =
      HTTPoison.post!("https://snirh.apambiente.pt/index.php?idMain=2&idItem=3", payload, headers)

    body
  end

  defp parse_row(row) do
    {"td", [],
     [
       {"a",
        [
          {"title", "Dados"},
          {"href", url},
          {"target", "_self"}
        ], [dam_code]}
     ]} = row

    # url = "/index.php?idRef=MTIyMw==&FILTRA_BACIA=138&FILTRA_COVER=920123705&FILTRA_SITE=1627758888"
    site_id =
      url
      |> String.split("&")
      |> List.last()
      |> String.split("=")
      |> List.last()

    {dam_code, site_id}
  end

  defp update_dam(dam_code, site_id) do
    Ecto.Adapters.SQL.query!(
      Barragenspt.Repo,
      "UPDATE dam SET site_id = '#{site_id}', updated_at = now() WHERE code = '#{dam_code}'",
      []
    )
  end
end
