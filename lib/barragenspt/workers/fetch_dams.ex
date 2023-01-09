defmodule Barragenspt.Workers.FetchDams do
  use Oban.Worker, queue: :dams_info
  import Ecto.Query
  alias Barragenspt.Services.Snirh, as: Snirh

  @impl Oban.Worker
  def perform(_args) do
    from(_x in Barragenspt.Hydrometrics.Dam) |> Barragenspt.Repo.delete_all()

    Snirh.dam_data()
    |> Floki.parse_document!()
    |> Floki.find("#dbasepesquisador_tbllistaresultados")
    |> hd()
    |> then(fn {"table", _first, rows} -> rows end)
    |> tl()
    |> Stream.map(fn row -> parse_row(row) end)
    |> Enum.reject(fn row -> row == :noop end)
    |> Stream.each(fn {basin_id, basin_name, dam_code, name, site_id} ->
      insert_dam(basin_id, basin_name, dam_code, name, site_id)
    end)
    |> Stream.run()

    :ok
  end

  defp parse_row({"tr", [], [_item1, item2, item3, item4 | _rest]}) do
    {"td", [],
     [
       {"a",
        [
          {"title", "Dados"},
          {"href", url},
          {"target", "_self"}
        ], [dam_code]}
     ]} = item2

    %{"FILTRA_BACIA" => basin_id, "FILTRA_SITE" => site_id} =
      url
      |> URI.parse()
      |> then(fn %URI{query: query} -> query end)
      |> URI.decode_query()

    {"td", [], [name]} = item3
    {"td", [], [basin_name]} = item4

    {basin_id, basin_name, dam_code, name, site_id}
  end

  defp parse_row(_does_not_matter) do
    :noop
  end

  defp insert_dam(basin_id, basin_name, dam_code, name, site_id) do
    formatted_name =
      name
      |> String.trim_leading("Albufeira Da")
      |> String.trim_leading("Albufeira De")
      |> String.trim_leading("Albufeira Do")
      |> String.trim_trailing("(R.E.)")
      |> String.trim_trailing()
      |> String.downcase()
      |> Recase.to_title()

    formatted_basin_name =
      basin_name
      |> String.downcase()
      |> Recase.to_title()

    dam = %Barragenspt.Hydrometrics.Dam{
      basin_id: basin_id,
      basin: formatted_basin_name,
      code: dam_code,
      name: formatted_name,
      site_id: site_id
    }

    Barragenspt.Repo.insert!(dam)
  end
end
