defmodule BarragensptWeb.CoreComponents do
  @moduledoc """
  Core UI components for auth and dashboard (Tailwind, barragens.pt styling).
  """
  use Phoenix.Component

  @doc """
  Renders a header with optional subtitle.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="text-lg font-semibold leading-8 text-slate-900 dark:text-slate-100">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="mt-1 text-sm text-slate-600 dark:text-slate-400">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  attr :rest, :global,
    include: ~w(href navigate patch method download name value disabled type role phx-disable-with formaction)

  attr :class, :string, default: nil
  attr :variant, :string, default: nil
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    base =
      "inline-flex w-full cursor-pointer items-center justify-center gap-2 rounded-lg px-4 py-2.5 text-sm font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-brand-500 focus:ring-offset-2 dark:focus:ring-offset-slate-900 disabled:opacity-50 sm:w-auto"

    variant_class =
      case assigns[:variant] do
        "primary" -> "bg-brand-600 text-white hover:bg-brand-700"
        _ -> "bg-brand-600 text-white hover:bg-brand-700"
      end

    merged = [base, variant_class, assigns[:class]] |> Enum.reject(&is_nil/1) |> Enum.join(" ")
    assigns = assign(assigns, :merged_class, merged)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@merged_class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@merged_class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options for select inputs"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :string, default: nil, doc: "extra classes for the input"
  attr :error_class, :string, default: nil, doc: "error state classes"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step phx-mounted)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="mb-3">
      <label class="flex items-start gap-2">
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={[@class || "mt-1 size-4 rounded border-slate-300 text-brand-600 focus:ring-brand-500 dark:border-slate-600 dark:bg-slate-800"]}
          {@rest}
        />
        <span :if={@label} class="text-sm text-slate-700 dark:text-slate-300">{@label}</span>
      </label>
      <p :for={msg <- @errors} class="mt-1.5 flex items-center gap-2 text-sm text-red-600 dark:text-red-400">
        <.icon name="hero-exclamation-circle" class="size-4 shrink-0" />
        {msg}
      </p>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="mb-3">
      <label class="block">
        <span :if={@label} class="mb-1 block text-sm font-medium text-slate-700 dark:text-slate-300">
          {@label}
        </span>
        <select
          id={@id}
          name={@name}
          class={[
            @class || "block w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-slate-900 shadow-sm focus:border-brand-500 focus:ring-brand-500 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100",
            @errors != [] && (@error_class || "border-red-500")
          ]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options || [], @value)}
        </select>
      </label>
      <p :for={msg <- @errors} class="mt-1.5 flex items-center gap-2 text-sm text-red-600 dark:text-red-400">
        <.icon name="hero-exclamation-circle" class="size-4 shrink-0" />
        {msg}
      </p>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="mb-3">
      <label class="block">
        <span :if={@label} class="mb-1 block text-sm font-medium text-slate-700 dark:text-slate-300">
          {@label}
        </span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class || "block w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-slate-900 shadow-sm focus:border-brand-500 focus:ring-brand-500 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100",
            @errors != [] && (@error_class || "border-red-500")
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <p :for={msg <- @errors} class="mt-1.5 flex items-center gap-2 text-sm text-red-600 dark:text-red-400">
        <.icon name="hero-exclamation-circle" class="size-4 shrink-0" />
        {msg}
      </p>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div class="mb-3">
      <label class="block">
        <span :if={@label} class="mb-1 block text-sm font-medium text-slate-700 dark:text-slate-300">
          {@label}
        </span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class || "block w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-slate-900 shadow-sm focus:border-brand-500 focus:ring-brand-500 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100",
            @errors != [] && (@error_class || "border-red-500")
          ]}
          {@rest}
        />
      </label>
      <p :for={msg <- @errors} class="mt-1.5 flex items-center gap-2 text-sm text-red-600 dark:text-red-400">
        <.icon name="hero-exclamation-circle" class="size-4 shrink-0" />
        {msg}
      </p>
    </div>
    """
  end

  attr :id, :string, default: nil
  attr :flash, :map, default: %{}
  attr :kind, :atom, values: [:info, :error]

  def flash(assigns) do
    kind = assigns.kind

    assigns =
      assigns
      |> assign_new(:id, fn -> "flash-#{kind}" end)
      |> assign(:msg, Phoenix.Flash.get(assigns.flash, kind))

    ~H"""
    <div
      :if={@msg}
      id={@id}
      role="alert"
      class={[
        "mb-4 rounded-lg px-4 py-3 text-sm",
        @kind == :info && "bg-brand-50 text-brand-900 dark:bg-brand-900/30 dark:text-brand-100",
        @kind == :error && "bg-red-50 text-red-900 dark:bg-red-900/30 dark:text-red-100"
      ]}
    >
      {@msg}
    </div>
    """
  end

  def flash_group(assigns) do
    ~H"""
    <.flash kind={:info} flash={@flash} />
    <.flash kind={:error} flash={@flash} />
    """
  end

  attr :name, :string, required: true
  attr :class, :string, default: "size-4"

  def icon(%{name: "hero-information-circle"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      stroke-width="1.5"
      stroke="currentColor"
      class={@class}
      aria-hidden="true"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="m11.25 11.25.041-.02a.75.75 0 0 1 1.063.852l-.708 2.836a.75.75 0 0 0 1.063.853l.041-.021M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9-3.75h.008v.008H12V8.25Z"
      />
    </svg>
    """
  end

  def icon(%{name: "hero-exclamation-circle"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      stroke-width="1.5"
      stroke="currentColor"
      class={@class}
      aria-hidden="true"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z"
      />
    </svg>
    """
  end

  def icon(%{name: "hero-x-mark"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      stroke-width="1.5"
      stroke="currentColor"
      class={@class}
      aria-hidden="true"
    >
      <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" />
    </svg>
    """
  end

  def icon(assigns) do
    ~H"""
    <span class={["inline-block", @class]} title={@name}>•</span>
    """
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end
