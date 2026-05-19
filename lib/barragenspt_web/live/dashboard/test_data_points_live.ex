defmodule BarragensptWeb.Dashboard.TestDataPointsLive do
  use BarragensptWeb, :live_view

  on_mount {BarragensptWeb.UserAuth, :require_authenticated}

  import Ecto.Query

  alias Barragenspt.Repo
  alias Barragenspt.Hydrometrics.Dams
  alias Barragenspt.Models.Hydrometrics.{Dam, DataPoint}
  alias Barragenspt.Workers.RefreshMaterializedViews

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       q: "",
       results: [],
       selected_site_id: nil,
       selected_name: nil,
       latest_point: nil,
       capacity_dam3: nil,
       value: "",
       use_pct: false,
       run_refresh: true
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl space-y-6">
        <.header>
          Ferramenta de teste: forçar valor de barragem
          <:subtitle>
            Apenas para desenvolvimento/testes. Insere um novo registo em `data_points` com `volume_last_hour`.
          </:subtitle>
        </.header>

        <div class="rounded-xl border border-amber-300 bg-amber-50 p-4 text-sm text-amber-900 dark:border-amber-700 dark:bg-amber-900/20 dark:text-amber-200">
          Use apenas em ambiente de teste. Esta ação pode disparar alertas reais para utilizadores.
        </div>

        <form phx-change="search" phx-submit="save" class="space-y-4 rounded-xl border border-slate-200 p-4 dark:border-slate-600">
          <div>
            <label for="force-dam-search" class="block text-sm font-medium text-slate-700 dark:text-slate-300">
              Barragem
            </label>
            <input
              id="force-dam-search"
              type="text"
              name="q"
              value={@q}
              phx-debounce="250"
              autocomplete="off"
              class="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm dark:border-slate-600 dark:bg-slate-800"
              placeholder="Pesquisar barragem..."
            />
            <input type="hidden" name="selected_site_id" value={@selected_site_id || ""} />
          </div>

          <%= if @results != [] do %>
            <ul class="max-h-56 overflow-y-auto rounded-lg border border-slate-200 dark:border-slate-600">
              <%= for r <- @results do %>
                <li>
                  <button
                    type="button"
                    phx-click="pick"
                    phx-value-id={r.id}
                    phx-value-name={r.name}
                    class="w-full px-3 py-2 text-left text-sm hover:bg-slate-100 dark:hover:bg-slate-700"
                  >
                    {r.name}
                  </button>
                </li>
              <% end %>
            </ul>
          <% end %>

          <%= if @selected_name do %>
            <p class="text-sm text-emerald-700 dark:text-emerald-300">
              Selecionada: <span class="font-semibold">{@selected_name}</span>
            </p>
          <% end %>

          <%= if @latest_point do %>
            <p class="text-xs text-slate-500 dark:text-slate-400">
              Último <span class="font-medium">volume_last_hour</span>: {format_decimal(@latest_point.value)} dam³
              <%= if @capacity_dam3 do %>
                (≈ {format_pct(decimal_to_float(@latest_point.value) / @capacity_dam3 * 100)} % ocupação)
              <% end %>
              — {format_naive_datetime(@latest_point.colected_at)}
            </p>
          <% end %>

          <%= if @capacity_dam3 do %>
            <p class="text-xs text-slate-600 dark:text-slate-400">
              Capacidade de referência: {@capacity_dam3} dam³ (conversão % ↔ volume)
            </p>
          <% else %>
            <p :if={@selected_site_id} class="text-xs text-amber-700 dark:text-amber-300">
              Capacidade desconhecida — o modo % não está disponível (use volume em dam³).
            </p>
          <% end %>

          <label class="inline-flex items-center gap-2 text-sm text-slate-700 dark:text-slate-300">
            <input type="checkbox" name="use_pct" value="true" checked={@use_pct} class="rounded" disabled={!@capacity_dam3} />
            Introduzir ocupação (%) em vez de volume (dam³)
          </label>

          <div>
            <label for="force-value" class="block text-sm font-medium text-slate-700 dark:text-slate-300">
              <%= if @use_pct do %>
                Nova ocupação (%)
              <% else %>
                Novo volume (dam³) — campo <span class="font-normal text-slate-500">volume_last_hour</span>
              <% end %>
            </label>
            <input
              id="force-value"
              type="text"
              name="value"
              value={@value}
              class="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm dark:border-slate-600 dark:bg-slate-800"
              placeholder={if @use_pct, do: "Ex: 85,5 (percentagem)", else: "Ex: 1234,5 (dam³)"}
              disabled={@use_pct && !@capacity_dam3}
            />
            <% cp = conversion_preview(@use_pct, @value, @capacity_dam3) %>
            <p :if={cp != ""} class="mt-1 text-xs text-slate-600 dark:text-slate-400">
              {cp}
            </p>
          </div>

          <label class="inline-flex items-center gap-2 text-sm text-slate-700 dark:text-slate-300">
            <input type="checkbox" name="run_refresh" value="true" checked={@run_refresh} class="rounded" />
            Atualizar materialized views imediatamente (para acelerar o trigger do alerta)
          </label>

          <div class="flex flex-wrap gap-2">
            <button
              type="submit"
              class="rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white hover:bg-brand-700"
            >
              Inserir valor de teste
            </button>
            <.link
              navigate={~p"/dashboard"}
              class="rounded-lg px-4 py-2 text-sm text-slate-600 hover:underline dark:text-slate-400"
            >
              Cancelar
            </.link>
          </div>
        </form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("search", params, socket) do
    q = params["q"] |> to_string() |> String.trim()
    selected_site_id = blank_to_nil(Map.get(params, "selected_site_id"))
    use_pct = use_pct?(params)
    run_refresh = run_refresh?(params)
    value_raw = Map.get(params, "value", socket.assigns.value) |> to_string()

    value =
      convert_value_on_mode_switch(
        socket.assigns.capacity_dam3,
        value_raw,
        socket.assigns.use_pct,
        use_pct
      )

    results =
      if q == "" do
        []
      else
        Dams.search_for_picker(q, []) |> Enum.take(20)
      end

    {:noreply,
     assign(socket,
       q: q,
       results: results,
       selected_site_id: selected_site_id,
       value: value,
       use_pct: use_pct,
       run_refresh: run_refresh
     )}
  end

  @impl true
  def handle_event("pick", %{"id" => site_id, "name" => name}, socket) do
    dam = Repo.get_by(Dam, site_id: site_id)
    capacity = if dam, do: dam_capacity(dam), else: nil
    latest_point = latest_volume_point(site_id)

    use_pct_effective = socket.assigns.use_pct && capacity != nil

    value =
      cond do
        use_pct_effective && latest_point ->
          vol = decimal_to_float(latest_point.value)
          format_compact(vol / capacity * 100)

        true ->
          latest_value_or_empty(latest_point)
      end

    {:noreply,
     assign(socket,
       selected_site_id: site_id,
       selected_name: name,
       q: name,
       results: [],
       latest_point: latest_point,
       capacity_dam3: capacity,
       value: value,
       use_pct: use_pct_effective
     )}
  end

  @impl true
  def handle_event("save", params, socket) do
    with {:ok, site_id} <- fetch_selected_site_id(params),
         %Dam{} = dam <- Repo.get_by(Dam, site_id: site_id),
         {:ok, volume_dam3} <- resolve_volume_for_insert(dam, params),
         {:ok, _} <- insert_test_data_point(dam, volume_dam3),
         {:ok, _maybe_job} <- maybe_enqueue_refresh(params) do
      latest_point = latest_volume_point(site_id)

      msg =
        if use_pct?(params) do
          "Inserido volume_last_hour ≈ #{format_compact(volume_dam3)} dam³ (a partir de #{params["value"]} %)."
        else
          "Valor de teste inserido com sucesso."
        end

      {:noreply,
       socket
       |> put_flash(:info, msg)
       |> assign(
         latest_point: latest_point,
         value: Map.get(params, "value", "") |> to_string(),
         run_refresh: run_refresh?(params),
         use_pct: use_pct?(params),
         capacity_dam3: dam_capacity(dam)
       )}
    else
      {:error, :missing_site} ->
        {:noreply, put_flash(socket, :error, "Selecione uma barragem antes de guardar.")}

      {:error, :invalid_value} ->
        {:noreply, put_flash(socket, :error, "Introduza um valor numérico válido.")}

      {:error, :no_capacity} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Capacidade da barragem desconhecida — não é possível converter % para volume."
         )}

      nil ->
        {:noreply, put_flash(socket, :error, "Barragem não encontrada.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Falha ao inserir valor: #{inspect(reason)}")}
    end
  end

  defp insert_test_data_point(%Dam{} = dam, value) do
    latest = latest_volume_point(dam.site_id)

    attrs =
      if latest do
        %{
          param_name: latest.param_name,
          param_id: latest.param_id,
          dam_code: latest.dam_code || dam.code,
          site_id: dam.site_id,
          basin_id: dam.basin_id,
          value: value,
          colected_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }
      else
        %{
          param_name: "volume_last_hour",
          param_id: "354895398",
          dam_code: dam.code,
          site_id: dam.site_id,
          basin_id: dam.basin_id,
          value: value,
          colected_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }
      end

    %DataPoint{}
    |> DataPoint.changeset(attrs)
    |> Repo.insert()
  end

  defp maybe_enqueue_refresh(params) do
    if run_refresh?(params) do
      Oban.insert(
        RefreshMaterializedViews.new(%{
          "trigger" => "test_force_dam_value",
          "site_id" => params["selected_site_id"]
        })
      )
    else
      {:ok, :skipped}
    end
  end

  defp run_refresh?(params) do
    Map.get(params, "run_refresh") in ["true", "on", "1"]
  end

  defp use_pct?(params) do
    Map.get(params, "use_pct") in ["true", "on", "1"]
  end

  defp resolve_volume_for_insert(%Dam{} = dam, params) do
    if use_pct?(params) do
      case dam_capacity(dam) do
        cap when is_integer(cap) and cap > 0 ->
          with {:ok, pct} <- parse_value(Map.get(params, "value")) do
            {:ok, pct / 100.0 * cap}
          end

        _ ->
          {:error, :no_capacity}
      end
    else
      parse_value(Map.get(params, "value"))
    end
  end

  defp convert_value_on_mode_switch(capacity, value_str, old_use_pct, new_use_pct)
       when capacity != nil and is_integer(capacity) and capacity > 0 and old_use_pct != new_use_pct do
    case parse_value(value_str) do
      {:ok, n} ->
        if new_use_pct do
          format_compact(n / capacity * 100)
        else
          format_compact(n / 100.0 * capacity)
        end

      _ ->
        value_str
    end
  end

  defp convert_value_on_mode_switch(_, value_str, _, _), do: value_str

  defp conversion_preview(true, value_str, capacity)
       when is_integer(capacity) and capacity > 0 do
    case parse_value(value_str) do
      {:ok, pct} ->
        vol = pct / 100.0 * capacity
        "→ volume_last_hour ≈ #{format_compact(vol)} dam³"

      _ ->
        ""
    end
  end

  defp conversion_preview(false, value_str, capacity)
       when is_integer(capacity) and capacity > 0 do
    case parse_value(value_str) do
      {:ok, vol} ->
        pct = vol / capacity * 100.0
        "→ ocupação ≈ #{format_pct(pct)} %"

      _ ->
        ""
    end
  end

  defp conversion_preview(_, _, _), do: ""

  defp dam_capacity(%Dam{total_capacity: cap})
       when is_integer(cap) and cap > 0,
       do: cap

  defp dam_capacity(%Dam{metadata: meta}) when is_map(meta) do
    case get_in(meta, ["Albufeira", "Capacidade total (dam3)"]) do
      s when is_binary(s) ->
        case Integer.parse(String.trim(s)) do
          {n, _} when n > 0 -> n
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp dam_capacity(_), do: nil

  defp decimal_to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp decimal_to_float(n) when is_float(n), do: n
  defp decimal_to_float(n) when is_integer(n), do: n * 1.0
  defp decimal_to_float(_), do: 0.0

  defp format_pct(n) when is_number(n), do: Float.round(n * 1.0, 1) |> :erlang.float_to_binary(decimals: 1)

  defp format_compact(n) when is_number(n) do
    :erlang.float_to_binary(n * 1.0, decimals: 4)
  end

  defp fetch_selected_site_id(params) do
    case blank_to_nil(Map.get(params, "selected_site_id")) do
      nil -> {:error, :missing_site}
      site_id -> {:ok, site_id}
    end
  end

  defp parse_value(v) when is_binary(v) do
    v =
      v
      |> String.trim()
      |> String.replace(",", ".")

    case Float.parse(v) do
      {n, _} -> {:ok, n}
      _ -> {:error, :invalid_value}
    end
  end

  defp parse_value(_), do: {:error, :invalid_value}

  defp blank_to_nil(v) when v in [nil, ""], do: nil
  defp blank_to_nil(v), do: v

  defp latest_volume_point(site_id) do
    Repo.one(
      from(dp in DataPoint,
        where: dp.site_id == ^site_id and dp.param_name == "volume_last_hour",
        order_by: [desc: dp.colected_at],
        limit: 1
      )
    )
  end

  defp latest_value_or_empty(nil), do: ""

  defp latest_value_or_empty(point) do
    format_decimal(point.value)
  end

  defp format_decimal(%Decimal{} = d), do: Decimal.to_string(d, :normal)
  defp format_decimal(v) when is_float(v), do: Float.to_string(v)
  defp format_decimal(v) when is_integer(v), do: Integer.to_string(v)
  defp format_decimal(_), do: ""

  defp format_naive_datetime(%NaiveDateTime{} = ndt) do
    Calendar.strftime(ndt, "%Y-%m-%d %H:%M:%S")
  end

  defp format_naive_datetime(_), do: "—"
end
