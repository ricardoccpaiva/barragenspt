defmodule BarragensptWeb.Dashboard.AlertFormLive do
  use BarragensptWeb, :live_view

  on_mount {BarragensptWeb.UserAuth, :require_authenticated}

  alias Barragenspt.Notifications
  alias Barragenspt.Notifications.AlertMetrics
  alias Barragenspt.Notifications.UserAlert
  alias Barragenspt.Hydrometrics.Dams

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl px-4 py-4 sm:px-6 sm:py-6">
        <div class="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm dark:border-slate-600 dark:bg-slate-800/50 md:grid md:min-h-[26rem] md:grid-cols-[minmax(0,148px)_1fr]">
          <%!-- Rail vertical (mock alternativa F) --%>
          <aside class="border-b border-slate-200 bg-gradient-to-b from-sky-50 to-stone-50 px-4 py-4 dark:border-slate-600 dark:from-slate-800/90 dark:to-slate-900/90 md:border-b-0 md:border-r md:px-3 md:py-5">
            <p class="text-[0.65rem] font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400">
              Assistente
            </p>
            <div class="mt-3 flex flex-row flex-wrap gap-x-4 gap-y-3 md:mt-4 md:flex-col md:flex-nowrap md:gap-y-0">
              <.wizard_rail_step
                num={1}
                title="Alvo"
                subtitle="Barragem"
                active={@step == 1}
                done={@step > 1}
                show_line={true}
              />
              <.wizard_rail_step
                num={2}
                title="Condição"
                subtitle="Indicador e limiar"
                active={@step == 2}
                done={@step > 2}
                show_line={true}
              />
              <.wizard_rail_step
                num={3}
                title="Notificações"
                subtitle="E-mail e repetição"
                active={@step == 3}
                done={false}
                show_line={false}
              />
            </div>
          </aside>

          <div class="flex min-h-0 flex-col p-4 sm:p-6">
            <h1 class="text-lg font-bold text-slate-900 dark:text-slate-100">
              {if @editing_alert_id, do: "Editar alerta", else: "Novo alerta"}
            </h1>
            <p class="mt-0.5 text-sm text-slate-500 dark:text-slate-400">Passo {@step} de 3</p>

            <div class="mt-5 flex-1 space-y-5">
              <%= if @step == 1 do %>
                <p class="text-sm font-semibold text-slate-800 dark:text-slate-200">
                  O que pretende monitorizar?
                </p>
                <div class="grid grid-cols-1 gap-2 sm:grid-cols-2">
                  <button
                    type="button"
                    phx-click="subject_type"
                    phx-value-type="dam"
                    class={subject_type_tile_class(@subject_type == "dam")}
                  >
                    <span class="text-xl leading-none">💧</span>
                    <span class="flex min-w-0 flex-col gap-0.5">
                      <span class="text-sm font-semibold">Barragem específica</span>
                      <span class="text-xs font-normal text-slate-500 dark:text-slate-400">
                        Uma albufeira
                      </span>
                    </span>
                  </button>
                </div>

                <form
                  phx-change="search"
                  phx-submit="search"
                  class="space-y-2"
                  id="alert-subject-search-form"
                >
                  <label
                    class="block text-sm font-medium text-slate-700 dark:text-slate-300"
                    for="alert-subject-q"
                  >
                    Pesquisar
                  </label>
                  <input
                    id="alert-subject-q"
                    type="text"
                    name="q"
                    value={@search_term}
                    phx-debounce="300"
                    autocomplete="off"
                    class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm dark:border-slate-600 dark:bg-slate-800"
                    placeholder="Nome da barragem…"
                  />
                </form>
                <ul class="max-h-48 overflow-y-auto rounded-lg border border-slate-200 dark:border-slate-600">
                  <%= for r <- @search_results do %>
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

              <%= if @step == 2 do %>
                <p class="text-sm font-semibold text-slate-800 dark:text-slate-200">Condição</p>
                <form
                  phx-change="field"
                  id="alert-condition-form"
                  class="space-y-3 rounded-xl border border-slate-200 bg-slate-50/50 p-4 dark:border-slate-600 dark:bg-slate-900/30"
                >
                  <div>
                    <label class="text-xs font-medium text-slate-600 dark:text-slate-400">
                      Indicador
                    </label>
                    <select
                      name="metric"
                      class="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm dark:border-slate-600 dark:bg-slate-800"
                    >
                      <%= for {value, label} <- metric_options(@subject_type) do %>
                        <option value={value} selected={@metric == value}>
                          {label}
                        </option>
                      <% end %>
                    </select>
                    <p :if={@subject_type == "dam"} class="mt-1 text-xs text-slate-500 dark:text-slate-400">
                      Inclui métricas de armazenamento, realtime e caudais médios diários.
                    </p>
                  </div>
                  <div>
                    <label class="text-xs font-medium text-slate-600 dark:text-slate-400">
                      Operador
                    </label>
                    <select
                      name="operator"
                      class="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm dark:border-slate-600 dark:bg-slate-800"
                    >
                      <option value="lt" selected={@operator == "lt"}>Inferior a (&lt;)</option>
                      <option value="gt" selected={@operator == "gt"}>Superior a (&gt;)</option>
                    </select>
                  </div>
                  <div>
                    <label class="text-xs font-medium text-slate-600 dark:text-slate-400">
                      Limiar
                    </label>
                    <input
                      type="number"
                      step="any"
                      name="threshold"
                      value={@threshold}
                      class="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm dark:border-slate-600 dark:bg-slate-800"
                    />
                  </div>
                </form>
                <p :if={@preview_value != nil} class="text-sm text-slate-600 dark:text-slate-400">
                  Valor atual (aprox.):
                  <span class="font-mono font-semibold">{format_num(@preview_value)}</span>
                </p>
                <p :if={@preview_value == nil} class="text-sm text-amber-700 dark:text-amber-300">
                  Não foi possível carregar o valor atual — pode guardar {if @editing_alert_id,
                    do: "as alterações.",
                    else: "o alerta."}
                </p>
              <% end %>

              <%= if @step == 3 do %>
                <p class="text-sm font-semibold text-slate-800 dark:text-slate-200">Notificações</p>
                <div class="space-y-3 rounded-xl border border-slate-200 bg-slate-50/50 p-4 dark:border-slate-600 dark:bg-slate-900/30">
                  <p class="text-sm text-slate-600 dark:text-slate-400">
                    E-mail:
                    <span class="font-medium text-slate-800 dark:text-slate-200">
                      {@current_scope.user.email}
                    </span>
                  </p>
                  <div>
                    <label class="block text-sm">
                      <input
                        type="radio"
                        name="repeat_mode"
                        value="once_per_event"
                        checked={@repeat_mode == "once_per_event"}
                        phx-click="repeat"
                        phx-value-mode="once_per_event"
                        class="mr-2 align-middle"
                      />
                      Uma vez por evento: notifica enquanto a condição se mantém; só volta a notificar depois de voltar a OK e a condição falhar novamente
                    </label>
                  </div>
                  <div>
                    <label class="block text-sm">
                      <input
                        type="radio"
                        name="repeat_mode"
                        value="cooldown"
                        checked={@repeat_mode == "cooldown"}
                        phx-click="repeat"
                        phx-value-mode="cooldown"
                        class="mr-2 align-middle"
                      /> Voltar a notificar a cada X horas enquanto a condição se mantiver
                    </label>
                    <input
                      :if={@repeat_mode == "cooldown"}
                      type="number"
                      min="1"
                      max="168"
                      name="cooldown_hours"
                      value={@cooldown_hours}
                      phx-change="field"
                      class="mt-2 w-24 rounded border border-slate-300 px-2 py-1 text-sm dark:border-slate-600 dark:bg-slate-800"
                    />
                  </div>
                  <div :if={Application.get_env(:barragenspt, :env) == :dev}>
                    <p class="mb-1 text-[0.65rem] font-semibold uppercase tracking-wide text-amber-700 dark:text-amber-400">
                      Apenas desenvolvimento
                    </p>
                    <label class="block text-sm">
                      <input
                        type="radio"
                        name="repeat_mode"
                        value="always"
                        checked={@repeat_mode == "always"}
                        phx-click="repeat"
                        phx-value-mode="always"
                        class="mr-2 align-middle"
                      />
                      <span class="font-medium text-amber-900 dark:text-amber-200">
                        Sempre
                      </span>
                      — envia e-mail em cada avaliação (ex.: a cada minuto) enquanto a condição se mantiver
                    </label>
                  </div>
                </div>
              <% end %>
            </div>

            <div class="mt-8 flex flex-wrap items-center gap-2 border-t border-slate-100 pt-5 dark:border-slate-700">
              <.link
                navigate={~p"/dashboard/alerts"}
                class="mr-auto text-sm font-semibold text-slate-600 underline decoration-slate-300 decoration-1 underline-offset-2 hover:text-slate-900 dark:text-slate-400 dark:hover:text-slate-200"
              >
                Cancelar
              </.link>
              <button
                :if={@step > 1}
                type="button"
                phx-click="back"
                class="rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50 dark:border-slate-600 dark:text-slate-200 dark:hover:bg-slate-700/50"
              >
                Anterior
              </button>
              <button
                :if={@step < 3}
                type="button"
                phx-click="next"
                disabled={!can_next?(@step, @subject_type, @subject_id, @subject_name)}
                class="rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-brand-700 disabled:cursor-not-allowed disabled:opacity-50"
              >
                Seguinte
              </button>
              <button
                :if={@step == 3}
                type="button"
                phx-click="save"
                class="rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-brand-700"
              >
                {if @editing_alert_id, do: "Guardar alterações", else: "Guardar alerta"}
              </button>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :num, :integer, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :active, :boolean, required: true
  attr :done, :boolean, required: true
  attr :show_line, :boolean, required: true

  def wizard_rail_step(assigns) do
    badge_class =
      cond do
        assigns.active ->
          "bg-brand-600 text-white shadow-sm ring-2 ring-brand-500/40 ring-offset-2 ring-offset-white dark:ring-offset-slate-900"

        assigns.done ->
          "bg-emerald-600 text-white"

        true ->
          "bg-slate-200 text-slate-600 dark:bg-slate-600 dark:text-slate-200"
      end

    assigns = assign(assigns, :badge_class, badge_class)

    ~H"""
    <div class="flex min-w-[10rem] shrink-0 gap-2 md:min-w-0">
      <div class="flex flex-col items-center">
        <span class={"flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-xs font-extrabold #{@badge_class}"}>
          {@num}
        </span>
        <div
          :if={@show_line}
          class="mt-1 hidden min-h-[1.25rem] w-px grow bg-slate-200 dark:bg-slate-600 md:block"
        />
      </div>
      <div class={if(@show_line, do: "pb-3", else: "")}>
        <p class="text-sm font-semibold leading-tight text-slate-900 dark:text-slate-100">{@title}</p>
        <p class="mt-0.5 max-w-[11rem] text-xs leading-snug text-slate-500 dark:text-slate-400">
          {@subtitle}
        </p>
      </div>
    </div>
    """
  end

  defp subject_type_tile_class(true) do
    "flex w-full items-start gap-3 rounded-lg border-2 border-brand-500 bg-sky-50 p-3 text-left transition hover:border-brand-600 dark:border-brand-400 dark:bg-brand-900/25"
  end

  defp subject_type_tile_class(false) do
    "flex w-full items-start gap-3 rounded-lg border-2 border-slate-200 bg-stone-50/80 p-3 text-left transition hover:border-slate-300 dark:border-slate-600 dark:bg-slate-800/50 dark:hover:border-slate-500"
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, new_form_socket(socket)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      case socket.assigns.live_action do
        :edit ->
          user_id = socket.assigns.current_scope.user.id

          case Notifications.get_alert(params["id"], user_id) do
            {:error, _} ->
              socket
              |> put_flash(:error, "Alerta não encontrado.")
              |> push_navigate(to: ~p"/dashboard/alerts")

            {:ok, alert} ->
              if alert.subject_type == "dam" do
                assign_from_alert(socket, alert)
              else
                socket
                |> put_flash(:error, "Este tipo de alerta já não é suportado.")
                |> push_navigate(to: ~p"/dashboard/alerts")
              end
          end

        :new ->
          new_form_socket(socket)
      end

    {:noreply, socket |> assign_preview()}
  end

  @impl true
  def handle_event("subject_type", %{"type" => t}, socket) do
    t = if t == "dam", do: t, else: "dam"

    {:noreply,
     socket
     |> assign(
       subject_type: t,
       subject_id: nil,
       subject_name: nil,
       metric: normalize_metric_for_subject(socket.assigns.metric, t),
       search_term: "",
       search_results: []
     )
     |> assign_preview()}
  end

  @impl true
  def handle_event("search", params, socket) when is_map(params) do
    q =
      params
      |> Map.get("q", "")
      |> case do
        v when is_binary(v) -> String.trim(v)
        _ -> ""
      end

    results =
      case socket.assigns.subject_type do
        "dam" ->
          if q == "" do
            []
          else
            Dams.search_for_picker(q, [])
            |> Enum.map(fn d -> %{id: d.id, name: d.name} end)
            |> Enum.take(15)
          end

        _ ->
          []
      end

    {:noreply, assign(socket, search_term: q, search_results: results)}
  end

  @impl true
  def handle_event("pick", %{"id" => id, "name" => name}, socket) do
    {:noreply,
     socket
     |> assign(subject_id: id, subject_name: name, search_results: [], search_term: name)
     |> assign_preview()}
  end

  @impl true
  def handle_event("field", params, socket) do
    metric =
      pick_field(params, "metric", socket.assigns.metric)
      |> normalize_metric_for_subject(socket.assigns.subject_type)

    operator = pick_field(params, "operator", socket.assigns.operator)
    threshold = pick_field(params, "threshold", socket.assigns.threshold)
    cooldown_hours = pick_field(params, "cooldown_hours", socket.assigns.cooldown_hours)

    {:noreply,
     socket
     |> assign(
       metric: metric,
       operator: operator,
       threshold: normalize_threshold_string(threshold),
       cooldown_hours: cooldown_hours
     )
     |> assign_preview()}
  end

  @impl true
  def handle_event("repeat", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, repeat_mode: mode)}
  end

  @impl true
  def handle_event("next", _, socket) do
    step = min(3, socket.assigns.step + 1)
    {:noreply, socket |> assign(:step, step) |> assign_preview()}
  end

  @impl true
  def handle_event("back", _, socket) do
    step = max(1, socket.assigns.step - 1)
    {:noreply, assign(socket, :step, step)}
  end

  @impl true
  def handle_event("save", params, socket) do
    user_id = socket.assigns.current_scope.user.id

    threshold_str =
      if map_size(params) > 0 do
        pick_field(params, "threshold", socket.assigns.threshold)
      else
        socket.assigns.threshold
      end

    t = parse_float(threshold_str)
    ch_raw = pick_field(params, "cooldown_hours", socket.assigns.cooldown_hours)
    ch = parse_int(ch_raw) || 24

    if t == nil do
      {:noreply, put_flash(socket, :error, "Introduza um limiar numérico válido.")}
    else
      do_save(socket, user_id, t, ch)
    end
  end

  defp do_save(socket, user_id, t, ch) do
    metric = normalize_metric_for_subject(socket.assigns.metric, socket.assigns.subject_type)

    base = %{
      subject_type: socket.assigns.subject_type,
      subject_id: normalize_subject_id(socket.assigns.subject_type, socket.assigns.subject_id),
      subject_name: socket.assigns.subject_name || "—",
      metric: metric,
      operator: socket.assigns.operator,
      threshold: t,
      repeat_mode: socket.assigns.repeat_mode,
      cooldown_hours: ch
    }

    case socket.assigns.editing_alert_id do
      nil ->
        attrs = Map.put(base, :user_id, user_id) |> Map.put(:active, true)

        case Notifications.create_alert(attrs) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Alerta criado.")
             |> push_navigate(to: ~p"/dashboard/alerts")}

          {:error, cs} ->
            {:noreply, put_flash(socket, :error, format_errors(cs))}
        end

      alert_id ->
        {:ok, existing} = Notifications.get_alert(alert_id, user_id)

        attrs =
          base
          |> Map.put(:user_id, user_id)
          |> Map.put(:active, existing.active)

        case Notifications.update_alert(alert_id, user_id, attrs) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Alerta atualizado.")
             |> push_navigate(to: ~p"/dashboard/alerts")}

          {:error, cs} ->
            {:noreply, put_flash(socket, :error, format_errors(cs))}
        end
    end
  end

  defp normalize_subject_id(_, id) when id in [nil, ""], do: nil

  defp normalize_subject_id(_, id) do
    cond do
      is_binary(id) -> id
      true -> to_string(id)
    end
  end

  defp new_form_socket(socket) do
    socket
    |> assign(
      editing_alert_id: nil,
      step: 1,
      subject_type: "dam",
      subject_id: nil,
      subject_name: nil,
      search_term: "",
      search_results: [],
      metric: "storage_pct",
      operator: "lt",
      threshold: "40",
      repeat_mode: "cooldown",
      cooldown_hours: "24",
      preview_value: nil
    )
  end

  defp assign_from_alert(socket, alert) do
    metric = normalize_metric_for_subject(alert.metric, alert.subject_type)

    sid =
      case alert.subject_id do
        nil ->
          nil

        id when is_binary(id) ->
          t = String.trim(id)
          if t == "", do: nil, else: t

        id ->
          id |> to_string() |> String.trim() |> then(&if(&1 == "", do: nil, else: &1))
      end

    socket
    |> assign(
      editing_alert_id: alert.id,
      step: 1,
      subject_type: alert.subject_type,
      subject_id: sid,
      subject_name: alert.subject_name,
      search_term:
        if(alert.subject_type == "dam", do: alert.subject_name || "", else: ""),
      search_results: [],
      metric: metric,
      operator: alert.operator,
      threshold: format_threshold_field(alert.threshold),
      repeat_mode: alert.repeat_mode,
      cooldown_hours: Integer.to_string(alert.cooldown_hours || 24),
      preview_value: nil
    )
  end

  defp can_next?(2, _, _, _), do: true

  defp can_next?(1, "dam", id, _),
    do: subject_id_present?(id)

  defp can_next?(1, _, _, _), do: false
  defp can_next?(s, _, _, _) when s > 2, do: true

  defp subject_id_present?(nil), do: false
  defp subject_id_present?(""), do: false

  defp subject_id_present?(s) when is_binary(s), do: String.trim(s) != ""

  defp subject_id_present?(_), do: true

  defp assign_preview(socket) do
    a = %{
      subject_type: socket.assigns.subject_type,
      subject_id: socket.assigns.subject_id,
      metric: socket.assigns.metric,
      operator: socket.assigns.operator,
      threshold: parse_float(socket.assigns.threshold) || 0
    }

    v =
      if socket.assigns.step >= 2 and ready_subject?(socket.assigns) do
        AlertMetrics.current_value(a)
      else
        nil
      end

    assign(socket, :preview_value, v)
  end

  defp ready_subject?(%{subject_type: "dam", subject_id: id}),
    do: subject_id_present?(id)

  defp ready_subject?(_), do: false

  defp metric_options(_subject_type) do
    [
      {"storage_pct", "Ocupação (%)"},
      {"month_change_pct", "Variação vs 1 mês (pp)"},
      {"year_change_pct", "Variação vs 1 ano (pp)"},
      {"realtime_level", "Cota (m, realtime)"},
      {"realtime_inflow", "Caudal afluente (m3/s, realtime)"},
      {"realtime_outflow", "Caudal efluente (m3/s, realtime)"},
      {"realtime_storage", "Volume armazenado (%, realtime)"},
      {"daily_discharged_flow", "Caudal descarregado médio diário (m3/s)"},
      {"daily_tributary_flow", "Caudal afluente médio diário (m3/s)"},
      {"daily_effluent_flow", "Caudal efluente médio diário (m3/s)"},
      {"daily_turbocharged_flow", "Caudal turbinado médio diário (m3/s)"}
    ]
  end

  defp normalize_metric_for_subject(metric, subject_type) do
    if UserAlert.realtime_metric?(metric) and subject_type != "dam" do
      "storage_pct"
    else
      metric
    end
  end

  defp pick_field(params, key, fallback) do
    params = stringify_form_params(params)

    if Map.has_key?(params, key) do
      Map.get(params, key)
    else
      fallback
    end
  end

  defp stringify_form_params(params) when is_map(params) do
    Map.new(params, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {to_string(k), v}
    end)
  end

  defp normalize_threshold_string(v) when is_binary(v) do
    v |> String.trim() |> String.replace(",", ".")
  end

  defp normalize_threshold_string(v), do: v

  defp parse_float(s) when is_binary(s) do
    s = s |> String.trim() |> String.replace(",", ".")

    case Float.parse(s) do
      {f, _} -> f
      _ -> nil
    end
  end

  defp parse_float(n) when is_number(n), do: n * 1.0
  defp parse_float(_), do: nil

  defp parse_int(s) when is_binary(s) do
    case Integer.parse(s) do
      {i, _} -> i
      _ -> nil
    end
  end

  defp parse_int(_), do: nil

  defp format_num(nil), do: "—"
  defp format_num(n), do: :erlang.float_to_binary(n * 1.0, decimals: 1)

  defp format_threshold_field(n) when is_float(n) do
    :erlang.float_to_binary(n, decimals: 10)
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
  end

  defp format_threshold_field(n) when is_integer(n), do: Integer.to_string(n)
  defp format_threshold_field(_), do: "0"

  defp format_errors(cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join("; ", fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end)
  end
end
