defmodule BarragensptWeb.Dashboard.DataPointsLive do
  use BarragensptWeb, :live_view

  import BarragensptWeb.DataPointsColectedAtCell
  import BarragensptWeb.DataPointsDamMultiselect
  import BarragensptWeb.DataPointsParamMultiselect
  import BarragensptWeb.DataPointsFilterSingleSelect

  import BarragensptWeb.DataPointsTableOpts,
    only: [
      table_opts_flex_fill: 1,
      flop_pagination_page_link_attrs: 0,
      flop_pagination_current_attrs: 0,
      flop_pagination_prev_attrs: 0,
      flop_pagination_next_attrs: 0,
      flop_pagination_disabled_attrs: 0
    ]

  import Flop.Phoenix

  on_mount {BarragensptWeb.UserAuth, :require_authenticated}

  alias Barragenspt.Hydrometrics.{Dams, DataPointParams}
  alias BarragensptWeb.DataPointsFilterDateClass
  alias Flop.Filter

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:data_points_export_href, ~p"/dashboard/data-points/export/csv")
      |> assign(:awaiting_param_filter, true)
      |> assign(:data_points_export_enabled, false)
      |> assign(:data_points_basins, Dams.list_data_points_filter_basins())
      |> assign(:data_points_dam_names, Dams.list_data_points_filter_dam_names())
      |> assign(:dam_multiselect_open, false)
      |> assign(:param_multiselect_open, false)
      |> assign(:data_points_single_select_open, nil)
      |> assign(:data_points_table_menu_open, false)
      |> assign(:data_points_chart_modal_open, false)
      |> assign(:data_points_chart_meta, nil)
      |> assign(:data_points_query_params, %{})

    {:ok,
     socket
     |> assign_filter_fields()
     |> assign(:table_opts, table_opts_flex_fill(true))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    export_href = data_points_export_csv_href(params)

    case Dams.list_data_points(params) do
      {:ok, {rows, meta}} ->
        case prune_dam_selection_for_basin(meta) do
          {:patch, patched_meta} ->
            to = Flop.Phoenix.build_path(~p"/dashboard/data-points", patched_meta)
            {:noreply, push_patch(socket, to: to)}

          :ok ->
            param_set? = Dams.data_points_param_name_filter_set?(meta.flop)
            awaiting = not param_set?
            dam_names = data_points_dam_names_for_basin(meta)

            {:noreply,
             socket
             |> assign(data_points: rows, meta: meta, form: to_form(meta))
             |> assign(:data_points_export_href, export_href)
             |> assign(:awaiting_param_filter, awaiting)
             |> assign(:data_points_export_enabled, param_set?)
             |> assign(:data_points_dam_names, dam_names)
             |> assign(:table_opts, table_opts_flex_fill(awaiting))
             |> assign(:data_points_table_menu_open, false)
             |> assign(:param_multiselect_open, false)
             |> assign(:data_points_query_params, params)
             |> assign(:data_points_chart_modal_open, false)
             |> assign(:data_points_chart_meta, nil)}
        end

      {:error, meta} ->
        dam_names = data_points_dam_names_for_basin(meta)

        {:noreply,
         socket
         |> put_flash(:error, "Parâmetros de filtro ou paginação inválidos.")
         |> assign(data_points: [], meta: meta, form: to_form(meta))
         |> assign(:data_points_export_href, export_href)
         |> assign(:awaiting_param_filter, true)
         |> assign(:data_points_export_enabled, false)
         |> assign(:data_points_dam_names, dam_names)
         |> assign(:table_opts, table_opts_flex_fill(true))
         |> assign(:data_points_table_menu_open, false)
         |> assign(:param_multiselect_open, false)
         |> assign(:data_points_query_params, params)
         |> assign(:data_points_chart_modal_open, false)
         |> assign(:data_points_chart_meta, nil)}
    end
  end

  @impl true
  def handle_event("update-filter", params, socket) do
    params =
      params
      |> Map.delete("_target")
      |> stringify_query_param_map()

    current = stringify_query_param_map(socket.assigns.data_points_query_params)

    merged_filters =
      merge_flop_filter_maps(
        Map.get(current, "filters") || %{},
        Map.get(params, "filters") || %{}
      )

    merged =
      current
      |> Map.drop(["filters"])
      |> Map.merge(Map.drop(params, ["filters"]))
      |> Map.put("filters", merged_filters)
      |> Map.drop(["_csrf_token", "_method"])

    query = Plug.Conn.Query.encode(merged)

    {:noreply, push_patch(socket, to: "/dashboard/data-points?" <> query)}
  end

  @impl true
  def handle_event("dam_multiselect_toggle", _, socket) do
    {:noreply, update(socket, :dam_multiselect_open, &(!&1))}
  end

  @impl true
  def handle_event("dam_multiselect_close", _, socket) do
    {:noreply, assign(socket, :dam_multiselect_open, false)}
  end

  @impl true
  def handle_event("param_multiselect_toggle", _, socket) do
    {:noreply, update(socket, :param_multiselect_open, &(!&1))}
  end

  @impl true
  def handle_event("param_multiselect_close", _, socket) do
    {:noreply, assign(socket, :param_multiselect_open, false)}
  end

  @impl true
  def handle_event("toggle_data_points_param", %{"slug" => slug}, socket) do
    slug = slug |> to_string()
    slugs = param_names_from_flop(socket.assigns.meta.flop)

    slugs =
      if slug in slugs,
        do: List.delete(slugs, slug),
        else: Enum.sort([slug | slugs])

    patch_param_names(socket, slugs)
  end

  def handle_event("toggle_data_points_param", _, socket), do: {:noreply, socket}

  @impl true
  def handle_event("clear_data_points_params", _, socket) do
    patch_param_names(socket, [])
  end

  @impl true
  def handle_event("data_points_single_select_toggle", %{"field" => field}, socket) do
    open = socket.assigns.data_points_single_select_open
    new_open = if open == field, do: nil, else: field
    {:noreply, assign(socket, :data_points_single_select_open, new_open)}
  end

  def handle_event("data_points_single_select_toggle", _, socket), do: {:noreply, socket}

  @impl true
  def handle_event("data_points_single_select_close", %{"field" => field}, socket) do
    if socket.assigns.data_points_single_select_open == field do
      {:noreply, assign(socket, :data_points_single_select_open, nil)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("data_points_table_menu_toggle", _, socket) do
    {:noreply,
     update(socket, :data_points_table_menu_open, fn open? -> not open? end)}
  end

  @impl true
  def handle_event("data_points_table_menu_close", _, socket) do
    {:noreply, assign(socket, :data_points_table_menu_open, false)}
  end

  @impl true
  def handle_event("open_data_points_chart", _, socket) do
    socket =
      socket
      |> assign(:data_points_chart_modal_open, true)
      |> assign(:data_points_table_menu_open, false)
      |> refresh_data_points_chart()

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_data_points_chart", _, socket) do
    {:noreply,
     socket
     |> assign(:data_points_chart_modal_open, false)
     |> assign(:data_points_chart_meta, nil)
     |> push_event("data-points-chart-data", %{chart: nil})}
  end

  def handle_event("data_points_single_select_close", _, socket), do: {:noreply, socket}

  @impl true
  def handle_event("set_data_points_single_filter", params, socket) do
    # Use phx-value-item, not phx-value-value: LiveView sets meta.value from the
    # button's DOM .value (empty for <button type="button">), which overwrites phx-value-value.
    field_s = params["field"] || params[:field]
    value = params["item"] || params[:item] || ""
    value = if is_binary(value), do: value, else: to_string(value)

    case to_string(field_s || "") do
      "basin" -> patch_eq_filter(socket, :basin, value)
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_data_points_dam", params, socket) do
    name = params["name"] || params[:name]
    name = name && to_string(name)

    if name in [nil, ""] do
      {:noreply, socket}
    else
      names = dam_names_from_flop(socket.assigns.meta.flop)
      names = if name in names, do: names -- [name], else: Enum.sort([name | names])
      patch_dam_names(socket, names)
    end
  end

  @impl true
  def handle_event("clear_data_points_dams", _, socket) do
    patch_dam_names(socket, [])
  end

  defp patch_dam_names(socket, names) do
    meta = socket.assigns.meta
    new_flop = put_dam_name_filters(meta.flop, names)
    to = Flop.Phoenix.build_path(~p"/dashboard/data-points", struct!(meta, flop: new_flop))
    {:noreply, push_patch(socket, to: to)}
  end

  defp patch_param_names(socket, slugs) do
    meta = socket.assigns.meta
    new_flop = put_param_name_filters(meta.flop, slugs)
    to = Flop.Phoenix.build_path(~p"/dashboard/data-points", struct!(meta, flop: new_flop))

    {:noreply,
     socket
     |> assign(:param_multiselect_open, false)
     |> push_patch(to: to)}
  end

  defp patch_eq_filter(socket, field, value) when field in [:basin] do
    meta = socket.assigns.meta
    new_flop = put_eq_filter(meta.flop, field, value) |> dam_names_pruned_to_basin(value)

    to = Flop.Phoenix.build_path(~p"/dashboard/data-points", struct!(meta, flop: new_flop))

    {:noreply,
     socket
     |> assign(:data_points_single_select_open, nil)
     |> push_patch(to: to)}
  end

  defp dam_names_pruned_to_basin(%Flop{} = flop, basin_value) when is_binary(basin_value) do
    basin_arg = if(basin_value == "", do: nil, else: basin_value)
    allowed = Dams.list_data_points_filter_dam_names(basin_arg) |> MapSet.new()
    names = dam_names_from_flop(flop) |> Enum.filter(&(&1 in allowed))
    put_dam_name_filters(flop, names)
  end

  # Drop dam selections that are not in the current basin list (e.g. basin changed via form).
  defp prune_dam_selection_for_basin(%Flop.Meta{flop: flop} = meta) do
    allowed = data_points_dam_names_for_basin(meta) |> MapSet.new()
    names = dam_names_from_flop(flop)
    pruned = Enum.filter(names, &(&1 in allowed))

    if pruned == names do
      :ok
    else
      {:patch, struct!(meta, flop: put_dam_name_filters(flop, pruned))}
    end
  end

  defp data_points_dam_names_for_basin(%Flop.Meta{} = meta) do
    basin_value = basin_value_from_flop(meta)
    Dams.list_data_points_filter_dam_names(if(basin_value == "", do: nil, else: basin_value))
  end

  defp data_points_export_csv_href(params) when is_map(params) do
    base = ~p"/dashboard/data-points/export/csv"

    case params do
      p when map_size(p) == 0 -> base
      p -> base <> "?" <> Plug.Conn.Query.encode(p)
    end
  end

  defp assign_filter_fields(socket) do
    assign(socket, :filter_fields, filter_field_configs(socket.assigns))
  end

  defp dam_names_from_flop(%Flop.Meta{flop: flop}), do: dam_names_from_flop(flop)

  defp dam_names_from_flop(%Flop{filters: filters}) do
    Enum.find_value(filters || [], fn
      %Flop.Filter{field: :dam_name, op: :in, value: v} when is_list(v) ->
        v

      %Flop.Filter{field: :dam_name, op: :==, value: v} when is_binary(v) and v != "" ->
        [v]

      %{field: :dam_name, op: op, value: v} ->
        cond do
          op in [:in, "in"] and is_list(v) -> v
          op in [:==, "=="] and is_binary(v) and v != "" -> [v]
          true -> nil
        end

      _ ->
        nil
    end) || []
  end

  defp dam_names_from_flop(_), do: []

  defp param_names_from_flop(%Flop.Meta{flop: flop}), do: param_names_from_flop(flop)

  defp param_names_from_flop(%Flop{filters: filters}) do
    Enum.find_value(filters || [], fn
      %Flop.Filter{field: f, op: :in, value: v} when f in [:param_name, "param_name"] and is_list(v) ->
        v |> Enum.filter(&is_binary/1) |> Enum.reject(&(&1 == "")) |> Enum.uniq() |> Enum.sort()

      %Flop.Filter{field: f, op: :==, value: v}
      when f in [:param_name, "param_name"] and is_binary(v) and v != "" ->
        [v]

      %{field: f, op: op, value: v} = fl ->
        cond do
          f in [:param_name, "param_name"] and op in [:in, "in"] and is_list(v) ->
            v |> Enum.filter(&is_binary/1) |> Enum.reject(&(&1 == "")) |> Enum.uniq() |> Enum.sort()

          f in [:param_name, "param_name"] and filter_op_eq?(fl) and is_binary(v) and v != "" ->
            [v]

          true ->
            nil
        end

      _ ->
        nil
    end) || []
  end

  defp param_names_from_flop(_), do: []

  defp put_param_name_filters(%Flop{filters: filters} = flop, slugs) do
    slugs = slugs |> Enum.filter(&is_binary/1) |> Enum.reject(&(&1 == "")) |> Enum.uniq() |> Enum.sort()
    base = (filters || []) |> Enum.reject(&param_name_flop_filter?/1)

    new_flop =
      if slugs == [] do
        %Flop{flop | filters: base}
      else
        %Flop{flop | filters: base ++ [%Filter{field: :param_name, op: :in, value: slugs}]}
      end

    new_flop
  end

  defp param_name_flop_filter?(%Flop.Filter{field: field}),
    do: field in [:param_name, "param_name"]

  defp param_name_flop_filter?(%{field: field}),
    do: field in [:param_name, "param_name"]

  defp param_name_flop_filter?(%{"field" => field}),
    do: field in ["param_name", :param_name]

  defp param_name_flop_filter?(_), do: false

  defp put_dam_name_filters(%Flop{filters: filters} = flop, names) do
    names = names |> Enum.uniq() |> Enum.sort()
    base = filters || []

    new_filters =
      Enum.map(base, fn f ->
        if dam_name_flop_filter?(f) do
          dam_filter_set_names(f, names)
        else
          f
        end
      end)

    # When dam_name was dropped as blank (normalize), there is no row to update—insert it.
    new_filters =
      if names != [] and not Enum.any?(new_filters, &dam_name_flop_filter?/1) do
        new_filters ++ [%Filter{field: :dam_name, op: :in, value: names}]
      else
        new_filters
      end

    %Flop{flop | filters: new_filters}
  end

  defp dam_name_flop_filter?(%Flop.Filter{field: field}),
    do: field in [:dam_name, "dam_name"]

  defp dam_name_flop_filter?(%{field: field}),
    do: field in [:dam_name, "dam_name"]

  defp dam_name_flop_filter?(%{"field" => field}),
    do: field in ["dam_name", :dam_name]

  defp dam_name_flop_filter?(_), do: false

  defp dam_filter_set_names(%Flop.Filter{} = f, names),
    do: %Flop.Filter{f | op: :in, value: names}

  defp dam_filter_set_names(%{} = f, names) do
    f
    |> Map.put(:op, :in)
    |> Map.put(:value, names)
  end

  defp put_eq_filter(%Flop{filters: filters} = flop, field, value)
       when field in [:basin] and is_binary(value) do
    base = (filters || []) |> Enum.reject(&eq_flop_filter_field?(&1, field))

    base =
      if value != "",
        do: base ++ [%Filter{field: field, op: :==, value: value}],
        else: base

    %Flop{flop | filters: base}
  end

  defp eq_flop_filter_field?(%Flop.Filter{field: f}, field),
    do: f in [field, Atom.to_string(field)]

  defp eq_flop_filter_field?(%{field: f}, field),
    do: f in [field, Atom.to_string(field)]

  defp eq_flop_filter_field?(%{"field" => f}, field) do
    f in [field, Atom.to_string(field), to_string(field)]
  end

  defp eq_flop_filter_field?(_, _), do: false

  defp chart_modal_param_summary(%Flop.Meta{} = meta) do
    meta
    |> param_names_from_flop()
    |> Enum.map(&DataPointParams.label/1)
    |> Enum.join(", ")
  end

  defp chart_modal_param_summary(_), do: ""

  defp basin_value_from_flop(%Flop.Meta{flop: flop}), do: basin_value_from_flop(flop)

  defp basin_value_from_flop(%Flop{filters: filters}) do
    Enum.find_value(filters || [], fn
      %Flop.Filter{field: f, op: :==, value: v} when f in [:basin, "basin"] and is_binary(v) ->
        v

      %{field: f, value: v} = fl ->
        if f in [:basin, "basin"] and filter_op_eq?(fl) and is_binary(v), do: v

      _ ->
        nil
    end)
    |> case do
      v when is_binary(v) -> v
      _ -> ""
    end
  end

  defp basin_value_from_flop(_), do: ""

  defp filter_op_eq?(%Flop.Filter{op: op}), do: op in [:==, "=="]
  defp filter_op_eq?(%{op: op}), do: op in [:==, "=="]
  defp filter_op_eq?(%{"op" => op}), do: op in [:==, "=="]
  defp filter_op_eq?(_), do: false

  defp param_options_for_multiselect do
    Enum.map(data_point_param_names(), fn slug ->
      {DataPointParams.label(slug), slug}
    end)
  end

  defp basin_filter_options(basins) do
    [{"— todas as bacias —", ""} | Enum.map(basins, fn basin -> {basin, basin} end)]
  end

  defp refresh_data_points_chart(socket) do
    params = socket.assigns.data_points_query_params

    case Dams.data_points_chart_series_for_ui(params, nil) do
      {:ok, rows, meta} ->
        grain = Map.get(meta, :grain, :day)
        chart = chart_js_payload_from_rows(rows, grain)

        socket
        |> assign(:data_points_chart_meta, meta)
        |> push_event("data-points-chart-data", %{chart: chart})

      {:error, :missing_param_name_filter} ->
        socket
        |> put_flash(:error, "Escolha pelo menos um parâmetro nos filtros para ver o gráfico.")
        |> assign(:data_points_chart_meta, nil)
        |> push_event("data-points-chart-data", %{chart: nil})

      {:error, %Flop.Meta{}} ->
        socket
        |> put_flash(:error, "Parâmetros de gráfico inválidos.")
        |> assign(:data_points_chart_meta, nil)
        |> push_event("data-points-chart-data", %{chart: nil})
    end
  end

  defp chart_js_payload_from_rows(rows, grain) when is_list(rows) do
    labels =
      rows
      |> Enum.map(& &1["bucket"])
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.sort()

    display_labels = Enum.map(labels, &format_chart_axis_label(&1, grain))

    param_slugs =
      rows
      |> Enum.map(& &1["param_name"])
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    multi_param? = length(param_slugs) > 1

    series =
      rows
      |> Enum.map(fn r -> {r["dam_name"], r["param_name"]} end)
      |> Enum.reject(fn {d, p} -> is_nil(d) or is_nil(p) end)
      |> Enum.uniq()
      |> Enum.sort()

    datasets =
      series
      |> Enum.with_index()
      |> Enum.map(fn {{dam, param_slug}, idx} ->
        color = chart_series_color(idx)

        label =
          if multi_param? do
            "#{dam} — #{DataPointParams.label(param_slug)}"
          else
            dam
          end

        data =
          Enum.map(labels, fn ts ->
            row =
              Enum.find(rows, fn r ->
                r["dam_name"] == dam && r["param_name"] == param_slug && r["bucket"] == ts
              end)

            if row, do: row["avg_value"], else: nil
          end)

        %{
          label: label,
          data: data,
          borderColor: color,
          backgroundColor: color <> "26",
          tension: 0.35,
          spanGaps: true,
          pointRadius: 2
        }
      end)

    %{labels: display_labels, datasets: datasets}
  end

  defp format_chart_axis_label(bucket_str, grain) when is_binary(bucket_str) do
    case parse_chart_bucket_naive(bucket_str) do
      {:ok, ndt} ->
        Calendar.strftime(ndt, chart_axis_strftime_pattern(grain))

      :error ->
        if byte_size(bucket_str) > 16, do: binary_part(bucket_str, 0, 16) <> "…", else: bucket_str
    end
  end

  defp format_chart_axis_label(_, _), do: "—"

  defp chart_axis_strftime_pattern(:hour), do: "%d/%m %H:%M"
  defp chart_axis_strftime_pattern(:day), do: "%d/%m/%Y"
  defp chart_axis_strftime_pattern(:week), do: "%d/%m/%Y"
  defp chart_axis_strftime_pattern(:month), do: "%m/%Y"
  defp chart_axis_strftime_pattern(_), do: "%d/%m/%Y"

  defp parse_chart_bucket_naive(str) do
    str = String.trim_trailing(str)

    case NaiveDateTime.from_iso8601(str) do
      {:ok, ndt} ->
        {:ok, ndt}

      {:error, _} ->
        case String.split(str, "T", parts: 2) do
          [date_part, _] ->
            case Date.from_iso8601(date_part) do
              {:ok, d} -> {:ok, NaiveDateTime.new!(d, ~T[00:00:00.000000])}
              {:error, _} -> :error
            end

          _ ->
            :error
        end
    end
  end

  defp chart_series_color(idx) do
    palette = [
      "#0ea5e9",
      "#6366f1",
      "#10b981",
      "#f59e0b",
      "#ef4444",
      "#8b5cf6",
      "#ec4899",
      "#14b8a6",
      "#f97316",
      "#84cc16"
    ]

    Enum.at(palette, rem(idx, length(palette)))
  end

  defp filter_field_configs(assigns) do
    basin_opts = basin_filter_options(assigns.data_points_basins)

    [
      {:param_name, [op: :in, label: "Parâmetro", type: "hidden"]},
      {:basin,
       [
         op: :==,
         label: "Bacia",
         type: "select",
         options: basin_opts
       ]},
      {:dam_name, [op: :in, label: "Barragem", type: "hidden"]},
      {:colected_at, [op: :>=, label: "Recolhido desde", type: "date"]},
      {:colected_at, [op: :<=, label: "Recolhido até", type: "date"]}
    ]
  end

  defp format_decimal(nil), do: "—"

  defp format_decimal(%Decimal{} = d) do
    d
    |> Decimal.round(4)
    |> Decimal.to_string(:normal)
  end

  defp data_point_param_names do
    [
      "volume_last_hour",
      "volume_last_day_month",
      "elevation_last_hour",
      "ouput_flow_rate_daily",
      "tributary_daily_flow",
      "effluent_daily_flow",
      "turbocharged_daily_flow"
    ]
  end

  defp stringify_query_param_map(params) when is_map(params) do
    Enum.into(params, %{}, fn {k, v} ->
      {to_string(k), stringify_query_param_value(v)}
    end)
  end

  defp stringify_query_param_value(v) when is_map(v), do: stringify_query_param_map(v)

  defp stringify_query_param_value(v) when is_list(v),
    do: Enum.map(v, &stringify_query_param_value/1)

  defp stringify_query_param_value(v), do: v

  defp merge_flop_filter_maps(current_filters, incoming_filters) do
    cur = filters_map_to_ordered_values(current_filters)
    inc = filters_map_to_ordered_values(incoming_filters)

    # Multiselect + Flop hidden rows often arrive as present-but-empty on form
    # events; restore from last URL when the row is missing or non-meaningful.
    # Basin: only restore when the row is fully absent so "" (todas) stays valid.
    merged_list =
      inc
      |> restore_multiselect_flop_row_from_url("param_name", cur)
      |> restore_multiselect_flop_row_from_url("dam_name", cur)
      |> restore_flop_row_from_url_if_absent("basin", cur)

    merged_list
    |> Enum.with_index()
    |> Map.new(fn {row, i} -> {Integer.to_string(i), row} end)
  end

  defp filters_map_to_ordered_values(filters) when filters == %{}, do: []

  defp filters_map_to_ordered_values(filters) when is_map(filters) do
    filters
    |> Enum.sort_by(fn {k, _} -> slot_index(k) end)
    |> Enum.map(fn {_k, v} -> stringify_query_param_map(v) end)
  end

  defp slot_index(k) do
    case Integer.parse(to_string(k)) do
      {i, _} -> i
      :error -> 0
    end
  end

  defp restore_multiselect_flop_row_from_url(incoming_rows, field, current_rows) do
    inc_row = Enum.find(incoming_rows, &(filter_row_field(&1) == field))
    cur_row = Enum.find(current_rows, &(filter_row_field(&1) == field))

    cond do
      cur_row == nil || not filter_row_meaningful_value?(cur_row) ->
        incoming_rows

      inc_row == nil ->
        incoming_rows ++ [cur_row]

      filter_row_meaningful_value?(inc_row) ->
        incoming_rows

      true ->
        incoming_rows
        |> Enum.reject(&(filter_row_field(&1) == field))
        |> Kernel.++([cur_row])
    end
  end

  defp restore_flop_row_from_url_if_absent(incoming_rows, field, current_rows) do
    if Enum.any?(incoming_rows, &(filter_row_field(&1) == field)) do
      incoming_rows
    else
      case Enum.find(current_rows, &(filter_row_field(&1) == field)) do
        nil -> incoming_rows
        row -> incoming_rows ++ [row]
      end
    end
  end

  defp filter_row_meaningful_value?(row) when is_map(row) do
    v = Map.get(row, "value") || Map.get(row, :value)
    flop_filter_value_nonempty?(v)
  end

  defp flop_filter_value_nonempty?(v) when is_binary(v), do: v != ""

  defp flop_filter_value_nonempty?(v) when is_list(v) do
    Enum.any?(v, fn
      x when is_binary(x) -> x != ""
      _ -> false
    end)
  end

  defp flop_filter_value_nonempty?(_), do: false

  defp filter_row_field(row) when is_map(row) do
    case Map.get(row, "field") || Map.get(row, :field) do
      f when is_atom(f) -> Atom.to_string(f)
      f when is_binary(f) -> f
      _ -> ""
    end
  end
end
