defmodule BarragensptWeb.Dashboard.DataPointsLive do
  use BarragensptWeb, :live_view

  import BarragensptWeb.DataPointsColectedAtCell
  import BarragensptWeb.DataPointsDamMultiselect
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

  alias Barragenspt.Hydrometrics.{Dams, DataPointParamLabels}
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
      |> assign(:data_points_single_select_open, nil)

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
             |> assign(:table_opts, table_opts_flex_fill(awaiting))}
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
         |> assign(:table_opts, table_opts_flex_fill(true))}
    end
  end

  @impl true
  def handle_event("update-filter", params, socket) do
    params = Map.delete(params, "_target")
    query = Plug.Conn.Query.encode(params)

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

  def handle_event("data_points_single_select_close", _, socket), do: {:noreply, socket}

  @impl true
  def handle_event("set_data_points_single_filter", params, socket) do
    # Use phx-value-item, not phx-value-value: LiveView sets meta.value from the
    # button's DOM .value (empty for <button type="button">), which overwrites phx-value-value.
    field_s = params["field"] || params[:field]
    value = params["item"] || params[:item] || ""
    value = if is_binary(value), do: value, else: to_string(value)

    case to_string(field_s || "") do
      "param_name" -> patch_eq_filter(socket, :param_name, value)
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

  defp patch_eq_filter(socket, field, value) when field in [:param_name, :basin] do
    meta = socket.assigns.meta
    new_flop = put_eq_filter(meta.flop, field, value)

    new_flop =
      if field == :basin do
        dam_names_pruned_to_basin(new_flop, value)
      else
        new_flop
      end

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

  defp date_filter_row_start?(%{label: "Recolhido desde"}), do: true
  defp date_filter_row_start?(_), do: false

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
       when field in [:param_name, :basin] and is_binary(value) do
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

  defp param_value_from_flop(%Flop.Meta{flop: flop}), do: param_value_from_flop(flop)

  defp param_value_from_flop(%Flop{filters: filters}) do
    Enum.find_value(filters || [], fn
      %Flop.Filter{field: f, op: :==, value: v} when f in [:param_name, "param_name"] and is_binary(v) ->
        v

      %{field: f, value: v} = fl ->
        if f in [:param_name, "param_name"] and filter_op_eq?(fl) and is_binary(v), do: v

      _ ->
        nil
    end)
    |> case do
      v when is_binary(v) -> v
      _ -> ""
    end
  end

  defp param_value_from_flop(_), do: ""

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

  defp param_filter_options do
    Enum.map(data_point_param_names(), fn slug ->
      {DataPointParamLabels.label(slug), slug}
    end)
    |> then(&([{"— escolher parâmetro —", ""} | &1]))
  end

  defp basin_filter_options(basins) do
    [{"— todas as bacias —", ""} | Enum.map(basins, fn basin -> {basin, basin} end)]
  end

  defp filter_field_configs(assigns) do
    param_opts = param_filter_options()
    basin_opts = basin_filter_options(assigns.data_points_basins)

    [
      {:param_name,
       [
         op: :==,
         label: "Parâmetro",
         type: "select",
         options: param_opts
       ]},
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
end
