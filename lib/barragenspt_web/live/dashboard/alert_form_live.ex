defmodule BarragensptWeb.Dashboard.AlertFormLive do
  use BarragensptWeb, :live_view

  on_mount {BarragensptWeb.UserAuth, :require_authenticated}

  alias Barragenspt.Hydrometrics.Dams
  alias Barragenspt.Notifications
  alias Barragenspt.Notifications.AlertMetrics
  alias Barragenspt.Notifications.UserAlert

  @max_step 4

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-5xl px-4 pb-4 pt-0 sm:px-6 sm:pb-6 sm:pt-1">
        <div class="-mt-4 mb-3 sm:-mt-6 sm:mb-4">
          <h1 class="text-lg font-semibold leading-8 text-slate-900 dark:text-slate-100">
            {if @editing_alert_id, do: "Editar alerta", else: "Criar alerta"}
          </h1>
        </div>

        <div class="grid gap-4 md:grid-cols-4">
          <.step_card
            num={1}
            title="Alvo"
            subtitle="Barragem"
            active={@step == 1}
            done={@step > 1}
          />
          <.step_card
            num={2}
            title="Condição"
            subtitle="Indicador e limiar"
            active={@step == 2}
            done={@step > 2}
          />
          <.step_card
            num={3}
            title="Notificações"
            subtitle="Repetição de e-mail"
            active={@step == 3}
            done={@step > 3}
          />
          <.step_card
            num={4}
            title="Revisão"
            subtitle="Confirmar e guardar"
            active={@step == 4}
            done={false}
          />
        </div>

        <div class="mt-4 h-2 overflow-hidden rounded-full bg-slate-200 dark:bg-slate-700">
          <div
            class="h-full bg-brand-600 transition-all duration-300"
            style={"width: #{round(@step / @max_step * 100)}%"}
          />
        </div>
        <p class="mt-1 text-xs text-slate-600 dark:text-slate-400">Passo {@step} de {@max_step}</p>

        <div class="mt-6 rounded-xl border border-slate-200 bg-white p-4 shadow-sm dark:border-slate-600 dark:bg-slate-800/50 sm:p-6">
          <%= if @step == 1 do %>
            <section class="space-y-4">
              <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
                Escolha o alvo do alerta
              </h2>
              <p class="text-sm text-slate-600 dark:text-slate-300">
                Neste momento os alertas são configurados para uma barragem específica.
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
                      Pesquisa pelo nome da albufeira
                    </span>
                  </span>
                </button>
              </div>

              <form
                phx-change="search"
                phx-submit="search"
                id="alert-search-form"
                class="space-y-2"
              >
                <label
                  for="alert-subject-q"
                  class="block text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  Pesquisar barragem
                </label>
                <input
                  id="alert-subject-q"
                  type="text"
                  name="q"
                  value={@search_term}
                  phx-debounce="300"
                  autocomplete="off"
                  class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm dark:border-slate-600 dark:bg-slate-800"
                  placeholder="Nome da barragem..."
                />
              </form>

              <ul
                :if={@search_results != []}
                class="max-h-56 overflow-y-auto rounded-lg border border-slate-200 dark:border-slate-600"
              >
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

              <p
                :if={@subject_name}
                class="text-sm font-medium text-emerald-700 dark:text-emerald-300"
              >
                Selecionado: {@subject_name}
              </p>

              <p :if={!can_next?(@step, assigns)} class="text-sm text-amber-700 dark:text-amber-300">
                Selecione uma barragem para continuar.
              </p>
            </section>
          <% end %>

          <%= if @step == 2 do %>
            <section class="space-y-4">
              <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
                Defina a condição
              </h2>
              <p class="text-sm text-slate-600 dark:text-slate-300">
                Escolha o indicador, o operador e o valor limite.
              </p>

              <form
                phx-change="field"
                id="alert-condition-form"
                class="grid grid-cols-1 gap-3 rounded-xl border border-slate-200 bg-slate-50/50 p-4 dark:border-slate-600 dark:bg-slate-900/30 md:grid-cols-3"
              >
                <div class="md:col-span-2">
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
                  <label class="text-xs font-medium text-slate-600 dark:text-slate-400">Limiar</label>
                  <input
                    type="number"
                    step="any"
                    name="threshold"
                    value={@threshold}
                    class="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm dark:border-slate-600 dark:bg-slate-800"
                  />
                </div>
              </form>

              <p
                :if={@preview_value != nil}
                class="rounded-lg bg-sky-50 px-3 py-2 text-sm text-sky-900 dark:bg-sky-900/20 dark:text-sky-200"
              >
                Valor atual aproximado:
                <span class="font-mono font-semibold">{format_num(@preview_value)}</span>
              </p>

              <p
                :if={!valid_threshold?(@threshold)}
                class="text-sm text-amber-700 dark:text-amber-300"
              >
                Introduza um limiar numérico válido para continuar.
              </p>
            </section>
          <% end %>

          <%= if @step == 3 do %>
            <section class="space-y-4">
              <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
                Configure notificações
              </h2>
              <p class="text-sm text-slate-600 dark:text-slate-300">
                O alerta envia e-mail para a sua conta: <strong>{@current_scope.user.email}</strong>
              </p>

              <div class="space-y-2">
                <button
                  type="button"
                  phx-click="repeat"
                  phx-value-mode="once_per_event"
                  class={repeat_mode_tile_class(@repeat_mode == "once_per_event")}
                >
                  <div class="text-sm font-semibold text-slate-900 dark:text-slate-100">
                    Uma vez por evento
                  </div>
                  <div class="text-xs text-slate-600 dark:text-slate-300">
                    Notifica na primeira quebra e só volta a notificar após regressar a OK.
                  </div>
                </button>

                <button
                  type="button"
                  phx-click="repeat"
                  phx-value-mode="cooldown"
                  class={repeat_mode_tile_class(@repeat_mode == "cooldown")}
                >
                  <div class="text-sm font-semibold text-slate-900 dark:text-slate-100">
                    Repetir com intervalo (cooldown)
                  </div>
                  <div class="text-xs text-slate-600 dark:text-slate-300">
                    Volta a notificar a cada X horas enquanto a condição se mantiver.
                  </div>
                </button>

                <div :if={@repeat_mode == "cooldown"} class="max-w-xs">
                  <label class="text-xs font-medium text-slate-600 dark:text-slate-400">
                    Intervalo em horas
                  </label>
                  <input
                    type="number"
                    min="1"
                    max="168"
                    name="cooldown_hours"
                    value={@cooldown_hours}
                    phx-change="field"
                    class="mt-1 w-full rounded border border-slate-300 px-2 py-1.5 text-sm dark:border-slate-600 dark:bg-slate-800"
                  />
                </div>

                <div :if={Application.get_env(:barragenspt, :env) == :dev}>
                  <button
                    type="button"
                    phx-click="repeat"
                    phx-value-mode="always"
                    class={repeat_mode_tile_class(@repeat_mode == "always")}
                  >
                    <div class="text-sm font-semibold text-amber-800 dark:text-amber-200">
                      Sempre (dev only)
                    </div>
                    <div class="text-xs text-amber-700 dark:text-amber-300">
                      Envia em todas as avaliações enquanto a condição for verdadeira.
                    </div>
                  </button>
                </div>
              </div>

              <p
                :if={!cooldown_valid?(@repeat_mode, @cooldown_hours)}
                class="text-sm text-amber-700 dark:text-amber-300"
              >
                Defina um intervalo entre 1 e 168 horas.
              </p>
            </section>
          <% end %>

          <%= if @step == 4 do %>
            <section class="space-y-4">
              <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
                Rever configuração
              </h2>
              <div class="rounded-xl border border-slate-200 bg-slate-50 p-4 text-sm dark:border-slate-600 dark:bg-slate-900/40">
                <dl class="grid grid-cols-1 gap-3 md:grid-cols-2">
                  <div>
                    <dt class="text-xs uppercase tracking-wide text-slate-500 dark:text-slate-400">
                      Alvo
                    </dt>
                    <dd class="font-medium text-slate-900 dark:text-slate-100">
                      {@subject_name || "—"}
                    </dd>
                  </div>
                  <div>
                    <dt class="text-xs uppercase tracking-wide text-slate-500 dark:text-slate-400">
                      Condição
                    </dt>
                    <dd class="font-medium text-slate-900 dark:text-slate-100">
                      {condition_sentence(@metric, @operator, @threshold)}
                    </dd>
                  </div>
                  <div>
                    <dt class="text-xs uppercase tracking-wide text-slate-500 dark:text-slate-400">
                      Repetição
                    </dt>
                    <dd class="font-medium text-slate-900 dark:text-slate-100">
                      {repeat_mode_sentence(@repeat_mode, @cooldown_hours)}
                    </dd>
                  </div>
                  <div>
                    <dt class="text-xs uppercase tracking-wide text-slate-500 dark:text-slate-400">
                      Destino
                    </dt>
                    <dd class="font-medium text-slate-900 dark:text-slate-100">
                      {@current_scope.user.email}
                    </dd>
                  </div>
                </dl>
              </div>

              <p :if={@preview_value != nil} class="text-sm text-slate-600 dark:text-slate-300">
                Valor atual aproximado:
                <span class="font-mono font-semibold">{format_num(@preview_value)}</span>
              </p>
            </section>
          <% end %>
        </div>

        <div class="sticky bottom-0 mt-4 flex flex-wrap items-center gap-2 rounded-xl border border-slate-200 bg-white/95 p-3 backdrop-blur dark:border-slate-600 dark:bg-slate-900/95">
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
            :if={@step < @max_step}
            type="button"
            phx-click="next"
            disabled={!can_next?(@step, assigns)}
            class="rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-brand-700 disabled:cursor-not-allowed disabled:opacity-50"
          >
            Seguinte
          </button>

          <button
            :if={@step == @max_step}
            type="button"
            phx-click="save"
            class="rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-brand-700"
          >
            {if @editing_alert_id, do: "Guardar alterações", else: "Guardar alerta"}
          </button>
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

  def step_card(assigns) do
    ~H"""
    <div class={[
      "rounded-xl border p-3 transition",
      @active && "border-brand-500 bg-brand-50/60 dark:border-brand-400 dark:bg-brand-900/20",
      @done && !@active &&
        "border-emerald-500 bg-emerald-50/50 dark:border-emerald-500 dark:bg-emerald-900/20",
      !@active && !@done && "border-slate-200 bg-white dark:border-slate-600 dark:bg-slate-800/50"
    ]}>
      <p class="text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
        Passo {@num}
      </p>
      <p class="mt-1 text-sm font-semibold text-slate-900 dark:text-slate-100">{@title}</p>
      <p class="text-xs text-slate-600 dark:text-slate-300">{@subtitle}</p>
    </div>
    """
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
    step = min(@max_step, socket.assigns.step + 1)
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

  defp new_form_socket(socket) do
    socket
    |> assign(
      editing_alert_id: nil,
      step: 1,
      max_step: @max_step,
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
      max_step: @max_step,
      subject_type: alert.subject_type,
      subject_id: sid,
      subject_name: alert.subject_name,
      search_term: if(alert.subject_type == "dam", do: alert.subject_name || "", else: ""),
      search_results: [],
      metric: metric,
      operator: alert.operator,
      threshold: format_threshold_field(alert.threshold),
      repeat_mode: alert.repeat_mode,
      cooldown_hours: Integer.to_string(alert.cooldown_hours || 24),
      preview_value: nil
    )
  end

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

  defp can_next?(1, assigns), do: ready_subject?(assigns)
  defp can_next?(2, assigns), do: valid_threshold?(assigns.threshold)
  defp can_next?(3, assigns), do: cooldown_valid?(assigns.repeat_mode, assigns.cooldown_hours)
  defp can_next?(_, _), do: true

  defp ready_subject?(%{subject_type: "dam", subject_id: id}), do: subject_id_present?(id)
  defp ready_subject?(_), do: false

  defp valid_threshold?(threshold), do: parse_float(threshold) != nil

  defp cooldown_valid?("cooldown", v) do
    case parse_int(v) do
      i when is_integer(i) -> i >= 1 and i <= 168
      _ -> false
    end
  end

  defp cooldown_valid?(_, _), do: true

  defp subject_id_present?(nil), do: false
  defp subject_id_present?(""), do: false
  defp subject_id_present?(s) when is_binary(s), do: String.trim(s) != ""
  defp subject_id_present?(_), do: true

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

  defp condition_sentence(metric, operator, threshold) do
    op = if operator == "lt", do: "inferior a", else: "superior a"
    "#{metric_label(metric)} #{op} #{threshold_with_unit(metric, threshold)}"
  end

  defp repeat_mode_sentence("once_per_event", _), do: "Uma vez por evento"

  defp repeat_mode_sentence("cooldown", cooldown_hours),
    do: "Repetir a cada #{cooldown_hours || "24"}h enquanto se mantiver"

  defp repeat_mode_sentence("always", _), do: "Sempre (dev only)"
  defp repeat_mode_sentence(_, _), do: "—"

  defp repeat_mode_tile_class(true) do
    "w-full rounded-lg border-2 border-brand-500 bg-brand-50 p-3 text-left dark:border-brand-400 dark:bg-brand-900/25"
  end

  defp repeat_mode_tile_class(false) do
    "w-full rounded-lg border border-slate-300 p-3 text-left hover:border-slate-400 dark:border-slate-600 dark:hover:border-slate-500"
  end

  defp subject_type_tile_class(true) do
    "flex w-full items-start gap-3 rounded-lg border-2 border-brand-500 bg-sky-50 p-3 text-left transition hover:border-brand-600 dark:border-brand-400 dark:bg-brand-900/25"
  end

  defp subject_type_tile_class(false) do
    "flex w-full items-start gap-3 rounded-lg border-2 border-slate-200 bg-stone-50/80 p-3 text-left transition hover:border-slate-300 dark:border-slate-600 dark:bg-slate-800/50 dark:hover:border-slate-500"
  end

  defp metric_label("storage_pct"), do: "Ocupação"
  defp metric_label("month_change_pct"), do: "Var. 1 mês"
  defp metric_label("year_change_pct"), do: "Var. 1 ano"
  defp metric_label("realtime_level"), do: "Cota (realtime)"
  defp metric_label("realtime_inflow"), do: "Caudal afluente (realtime)"
  defp metric_label("realtime_outflow"), do: "Caudal efluente (realtime)"
  defp metric_label("realtime_storage"), do: "Volume armazenado (realtime)"
  defp metric_label("daily_discharged_flow"), do: "Caudal descarregado médio diário"
  defp metric_label("daily_tributary_flow"), do: "Caudal afluente médio diário"
  defp metric_label("daily_effluent_flow"), do: "Caudal efluente médio diário"
  defp metric_label("daily_turbocharged_flow"), do: "Caudal turbinado médio diário"
  defp metric_label(_), do: "Indicador"

  defp threshold_with_unit(metric, threshold)
       when metric in [
              "realtime_inflow",
              "realtime_outflow",
              "daily_discharged_flow",
              "daily_tributary_flow",
              "daily_effluent_flow",
              "daily_turbocharged_flow"
            ],
       do: "#{threshold} m3/s"

  defp threshold_with_unit("realtime_level", threshold), do: "#{threshold} m"
  defp threshold_with_unit("storage_pct", threshold), do: "#{threshold}%"
  defp threshold_with_unit("month_change_pct", threshold), do: "#{threshold} pp"
  defp threshold_with_unit("year_change_pct", threshold), do: "#{threshold} pp"
  defp threshold_with_unit("realtime_storage", threshold), do: "#{threshold}%"
  defp threshold_with_unit(_, threshold), do: to_string(threshold)

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

  defp normalize_subject_id(_, id) when id in [nil, ""], do: nil

  defp normalize_subject_id(_, id) do
    cond do
      is_binary(id) -> id
      true -> to_string(id)
    end
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

  defp parse_int(i) when is_integer(i), do: i
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
