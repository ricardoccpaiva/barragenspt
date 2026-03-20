defmodule BarragensptWeb.Dashboard.AlertFormLive do
  use BarragensptWeb, :live_view

  on_mount {BarragensptWeb.UserAuth, :require_authenticated}

  alias Barragenspt.Notifications
  alias Barragenspt.Notifications.AlertMetrics
  alias Barragenspt.Hydrometrics.{Dams, Basins}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-lg space-y-6">
        <.header>
          {if @editing_alert_id, do: "Edit alert", else: "New alert"}
          <:subtitle>
            Step {@step} of 3
          </:subtitle>
        </.header>

        <%= if @step == 1 do %>
          <p class="text-sm text-slate-600 dark:text-slate-400">What do you want to watch?</p>
          <div class="grid gap-3">
            <button
              type="button"
              phx-click="subject_type"
              phx-value-type="dam"
              class={"rounded-xl border p-4 text-left transition #{if @subject_type == "dam", do: "border-brand-500 bg-brand-50 dark:bg-brand-900/20", else: "border-slate-200 dark:border-slate-600"}"}
            >
              💧 Specific dam
            </button>
            <button
              type="button"
              phx-click="subject_type"
              phx-value-type="basin"
              class={"rounded-xl border p-4 text-left transition #{if @subject_type == "basin", do: "border-brand-500 bg-brand-50 dark:bg-brand-900/20", else: "border-slate-200 dark:border-slate-600"}"}
            >
              🏞 River basin
            </button>
            <button
              type="button"
              phx-click="subject_type"
              phx-value-type="national"
              class={"rounded-xl border p-4 text-left transition #{if @subject_type == "national", do: "border-brand-500 bg-brand-50 dark:bg-brand-900/20", else: "border-slate-200 dark:border-slate-600"}"}
            >
              🇵🇹 Portugal (basin average)
            </button>
          </div>

          <%= if @subject_type in ["dam", "basin"] do %>
            <%!-- form wrapper so phx-change serializes field "q" (bare inputs outside forms often omit it) --%>
            <form phx-change="search" phx-submit="search" class="pt-2" id="alert-subject-search-form">
              <label class="block text-sm font-medium text-slate-700 dark:text-slate-300" for="alert-subject-q">
                Search
              </label>
              <input
                id="alert-subject-q"
                type="text"
                name="q"
                value={@search_term}
                phx-debounce="300"
                autocomplete="off"
                class="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm dark:border-slate-600 dark:bg-slate-800"
                placeholder={if @subject_type == "dam", do: "Dam name…", else: "Basin name…"}
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

          <%= if @subject_type == "national" or (@subject_id != nil and @subject_name != nil) do %>
            <p class="text-sm text-emerald-700 dark:text-emerald-300">
              Selection: <span class="font-semibold">{@subject_name}</span>
            </p>
          <% end %>
        <% end %>

        <%= if @step == 2 do %>
          <p class="text-sm font-medium text-slate-700 dark:text-slate-300">Condition</p>
          <%!-- One form so phx-change always sends metric, operator, and threshold together (avoids losing % threshold). --%>
          <form
            phx-change="field"
            id="alert-condition-form"
            class="space-y-3 rounded-xl border border-slate-200 p-4 dark:border-slate-600"
          >
            <div>
              <label class="text-xs font-medium text-slate-500">Metric</label>
              <select
                name="metric"
                class="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm dark:border-slate-600 dark:bg-slate-800"
              >
                <option value="storage_pct" selected={@metric == "storage_pct"}>Storage %</option>
                <option value="month_change_pct" selected={@metric == "month_change_pct"}>
                  Change vs 1 month (pp)
                </option>
                <option value="year_change_pct" selected={@metric == "year_change_pct"}>
                  Change vs 1 year (pp)
                </option>
              </select>
            </div>
            <div>
              <label class="text-xs font-medium text-slate-500">Operator</label>
              <select
                name="operator"
                class="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm dark:border-slate-600 dark:bg-slate-800"
              >
                <option value="lt" selected={@operator == "lt"}>Less than (&lt;)</option>
                <option value="gt" selected={@operator == "gt"}>Greater than (&gt;)</option>
              </select>
            </div>
            <div>
              <label class="text-xs font-medium text-slate-500">Threshold</label>
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
            Current value (approx.): <span class="font-mono font-semibold">{format_num(@preview_value)}</span>
          </p>
          <p :if={@preview_value == nil} class="text-sm text-amber-700 dark:text-amber-300">
            Could not load the current value — you can still save <%= if @editing_alert_id, do: "changes.", else: "the alert." %>
          </p>
        <% end %>

        <%= if @step == 3 do %>
          <p class="text-sm font-medium text-slate-700 dark:text-slate-300">Notifications</p>
          <div class="space-y-3 rounded-xl border border-slate-200 p-4 dark:border-slate-600">
            <p class="text-sm text-slate-600 dark:text-slate-400">
              Email: <span class="font-medium">{@current_scope.user.email}</span>
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
                  class="mr-2"
                />
                Once per period while the condition holds (notify again after it returns to OK and fails later)
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
                  class="mr-2"
                />
                Re-notify every X hours while the condition holds
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
          </div>
        <% end %>

        <div class="flex flex-wrap gap-2 pt-2">
          <button
            :if={@step > 1}
            type="button"
            phx-click="back"
            class="rounded-lg border border-slate-300 px-4 py-2 text-sm dark:border-slate-600"
          >
            Back
          </button>
          <button
            :if={@step < 3}
            type="button"
            phx-click="next"
            disabled={!can_next?(@step, @subject_type, @subject_id, @subject_name)}
            class="rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white hover:bg-brand-700 disabled:opacity-50"
          >
            Next
          </button>
          <button
            :if={@step == 3}
            type="button"
            phx-click="save"
            class="rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white hover:bg-brand-700"
          >
            <%= if @editing_alert_id, do: "Save changes", else: "Save alert" %>
          </button>
          <.link
            navigate={~p"/dashboard/alerts"}
            class="rounded-lg px-4 py-2 text-sm text-slate-600 hover:underline dark:text-slate-400"
          >
            Cancel
          </.link>
        </div>
      </div>
    </Layouts.app>
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
              |> put_flash(:error, "Alert not found.")
              |> push_navigate(to: ~p"/dashboard/alerts")

            {:ok, alert} ->
              assign_from_alert(socket, alert)
          end

        :new ->
          new_form_socket(socket)
      end

    {:noreply, socket |> assign_preview()}
  end

  @impl true
  def handle_event("subject_type", %{"type" => t}, socket) do
    {id, name, results} =
      case t do
        "national" -> {nil, "Portugal (basin average)", []}
        _ -> {nil, nil, []}
      end

    {:noreply,
     socket
     |> assign(subject_type: t, subject_id: id, subject_name: name, search_term: "", search_results: results)
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

        "basin" ->
          if q == "" do
            []
          else
            q_low = String.downcase(q)

            Basins.all()
            |> Enum.filter(fn b ->
              String.contains?(String.downcase(b.name || ""), q_low) or
                String.contains?(String.downcase(b.id || ""), q_low)
            end)
            |> Enum.map(fn b -> %{id: b.id, name: b.name} end)
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
    metric = pick_field(params, "metric", socket.assigns.metric)
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
      {:noreply, put_flash(socket, :error, "Enter a valid numeric threshold.")}
    else
      do_save(socket, user_id, t, ch)
    end
  end

  defp do_save(socket, user_id, t, ch) do
    base = %{
      subject_type: socket.assigns.subject_type,
      subject_id: normalize_subject_id(socket.assigns.subject_type, socket.assigns.subject_id),
      subject_name: socket.assigns.subject_name || "—",
      metric: socket.assigns.metric,
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
             |> put_flash(:info, "Alert created.")
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
             |> put_flash(:info, "Alert updated.")
             |> push_navigate(to: ~p"/dashboard/alerts")}

          {:error, cs} ->
            {:noreply, put_flash(socket, :error, format_errors(cs))}
        end
    end
  end

  defp normalize_subject_id("national", _), do: nil
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
      subject_type: nil,
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
    sid =
      case alert.subject_id do
        nil -> nil
        id when is_binary(id) -> id
        id -> to_string(id)
      end

    socket
    |> assign(
      editing_alert_id: alert.id,
      step: 1,
      subject_type: alert.subject_type,
      subject_id: sid,
      subject_name: alert.subject_name,
      search_term:
        if(alert.subject_type in ["dam", "basin"],
          do: alert.subject_name || "",
          else: ""
        ),
      search_results: [],
      metric: alert.metric,
      operator: alert.operator,
      threshold: format_threshold_field(alert.threshold),
      repeat_mode: alert.repeat_mode,
      cooldown_hours: Integer.to_string(alert.cooldown_hours || 24),
      preview_value: nil
    )
  end

  defp format_threshold_field(n) when is_float(n) do
    :erlang.float_to_binary(n, decimals: 10)
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
  end

  defp format_threshold_field(n) when is_integer(n), do: Integer.to_string(n)
  defp format_threshold_field(_), do: "0"

  defp can_next?(2, _, _, _), do: true
  defp can_next?(1, "national", _, name), do: name != nil
  defp can_next?(1, type, id, _) when type in ["dam", "basin"], do: id != nil
  defp can_next?(1, _, _, _), do: false
  defp can_next?(s, _, _, _) when s > 2, do: true

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

  defp ready_subject?(%{subject_type: "national"}), do: true
  defp ready_subject?(%{subject_type: t, subject_id: id}) when t in ["dam", "basin"], do: id != nil
  defp ready_subject?(_), do: false

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

  defp format_errors(cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join("; ", fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end)
  end
end
