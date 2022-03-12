defmodule BarragensptWeb.HomepageLive do
  use BarragensptWeb, :live_view

  alias Barragenspt.Mappers.Colors
  alias Barragenspt.Hydrometrics.Basins

  def mount(_, _, socket) do
    all_basins = Basins.all()
    data_to_feed = Basins.monthly_stats_for_basins()

    lines =
      Enum.map(all_basins, fn %{id: id, name: basin_name} ->
        %{k: basin_name, v: Colors.lookup(id)}
      end)

    socket =
      socket
      |> push_event("update_chart", %{data: data_to_feed, lines: lines})
      |> push_event("zoom_map", %{})

    {:ok, socket}
  end

  def handle_params(%{"page" => page}, _, socket) do
    {basins_summary, paging_info} = get_data(page)

    socket =
      socket
      |> assign(basins_summary: basins_summary)
      |> assign(paging_info)

    {:noreply, socket}
  end

  def handle_params(_, session, socket) do
    handle_params(%{"page" => 1}, session, socket)
  end

  defp get_data(page) do
    %{
      entries: entries,
      page_number: page_number,
      page_size: page_size,
      total_entries: total_entries,
      total_pages: total_pages
    } = Basins.summary_stats(%{page_size: 6, page: page})

    basins_summary =
      Enum.map(entries, fn {basin_id, name, current_storage, value} ->
        %{
          id: basin_id,
          name: name,
          current_storage: current_storage,
          average_historic_value: value,
          capacity_color: current_storage |> Decimal.to_float() |> Colors.lookup_capacity()
        }
      end)

    {basins_summary,
     %{
       page_number: page_number,
       page_size: page_size,
       total_entries: total_entries,
       total_pages: total_pages
     }}
  end
end
