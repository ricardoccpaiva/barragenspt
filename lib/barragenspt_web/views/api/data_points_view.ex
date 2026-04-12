defmodule BarragensptWeb.Api.DataPointsView do
  use BarragensptWeb, :view

  def render("index.json", %{rows: rows, meta: meta}) do
    %{
      data: Enum.map(rows, &data_point_row/1),
      meta: pagination_meta(meta),
      links: %{
        self: "/api/data-points",
        param_catalog: "/api/data-points/params"
      }
    }
  end

  defp data_point_row(r) do
    %{
      id: r.id,
      dam_name: r.dam_name,
      basin: r.basin,
      river: r.river,
      param_id: r.param_id,
      param_name: r.param_name,
      value: decimal_to_api_string(r.value),
      colected_at: naive_to_iso8601(r.colected_at)
    }
  end

  defp pagination_meta(%Flop.Meta{} = meta) do
    %{
      total_count: meta.total_count,
      page_size: meta.page_size,
      current_page: meta.current_page,
      total_pages: meta.total_pages,
      has_next_page: meta.has_next_page?,
      has_previous_page: meta.has_previous_page?
    }
  end

  defp decimal_to_api_string(nil), do: nil

  defp decimal_to_api_string(%Decimal{} = d), do: Decimal.to_string(d)

  defp naive_to_iso8601(nil), do: nil

  defp naive_to_iso8601(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_iso8601(ndt)
end
