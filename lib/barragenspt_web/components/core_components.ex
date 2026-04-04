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
    include:
      ~w(href navigate patch method download name value disabled type role phx-disable-with formaction)

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
                multiple pattern placeholder readonly required rows size step phx-mounted phx-change
                phx-debounce)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_field_error/1))
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
          class={[
            @class ||
              "mt-1 size-4 rounded border-slate-300 text-brand-600 focus:ring-brand-500 dark:border-slate-600 dark:bg-slate-800"
          ]}
          {@rest}
        />
        <span :if={@label} class="text-sm text-slate-700 dark:text-slate-300">{@label}</span>
      </label>
      <p
        :for={msg <- @errors}
        class="mt-1.5 flex items-center gap-2 text-sm text-red-600 dark:text-red-400"
      >
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
            @class ||
              "block w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-slate-900 shadow-sm focus:border-brand-500 focus:ring-brand-500 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100",
            @errors != [] && (@error_class || "border-red-500")
          ]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options || [], @value)}
        </select>
      </label>
      <p
        :for={msg <- @errors}
        class="mt-1.5 flex items-center gap-2 text-sm text-red-600 dark:text-red-400"
      >
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
            @class ||
              "block w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-slate-900 shadow-sm focus:border-brand-500 focus:ring-brand-500 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100",
            @errors != [] && (@error_class || "border-red-500")
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <p
        :for={msg <- @errors}
        class="mt-1.5 flex items-center gap-2 text-sm text-red-600 dark:text-red-400"
      >
        <.icon name="hero-exclamation-circle" class="size-4 shrink-0" />
        {msg}
      </p>
    </div>
    """
  end

  def input(%{type: "date"} = assigns) do
    assigns =
      assign(assigns, :date_value, normalize_date_input_value(Map.get(assigns, :value)))

    ~H"""
    <div class="mb-3">
      <label class="block">
        <span :if={@label} class="mb-1 block text-sm font-medium text-slate-700 dark:text-slate-300">
          {@label}
        </span>
        <input
          type="date"
          name={@name}
          id={@id}
          value={@date_value}
          class={[
            @class ||
              "block w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-slate-900 shadow-sm focus:border-brand-500 focus:ring-brand-500 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100",
            @errors != [] && (@error_class || "border-red-500")
          ]}
          {@rest}
        />
      </label>
      <p
        :for={msg <- @errors}
        class="mt-1.5 flex items-center gap-2 text-sm text-red-600 dark:text-red-400"
      >
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
            "block w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-slate-900 shadow-sm focus:border-brand-500 focus:ring-brand-500 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100",
            @class,
            @errors != [] && (@error_class || "border-red-500")
          ]}
          {@rest}
        />
      </label>
      <p
        :for={msg <- @errors}
        class="mt-1.5 flex items-center gap-2 text-sm text-red-600 dark:text-red-400"
      >
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

  def icon(%{name: "hero-ellipsis-vertical"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="currentColor"
      class={@class}
      aria-hidden="true"
    >
      <circle cx="12" cy="6" r="1.5" />
      <circle cx="12" cy="12" r="1.5" />
      <circle cx="12" cy="18" r="1.5" />
    </svg>
    """
  end

  def icon(%{name: "hero-clock"} = assigns) do
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
        d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"
      />
    </svg>
    """
  end

  def icon(%{name: "hero-pencil-square"} = assigns) do
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
        d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931Zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0 1 15.75 21H5.25A2.25 2.25 0 0 1 3 18.75V8.25A2.25 2.25 0 0 1 5.25 6H10"
      />
    </svg>
    """
  end

  def icon(%{name: "hero-pause"} = assigns) do
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
      <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 5.25v13.5m-7.5-13.5v13.5" />
    </svg>
    """
  end

  def icon(%{name: "hero-play"} = assigns) do
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
        d="M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.348a1.125 1.125 0 0 1 0 1.971l-11.54 6.347a1.125 1.125 0 0 1-1.667-.985V5.653Z"
      />
    </svg>
    """
  end

  def icon(%{name: "hero-trash"} = assigns) do
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
        d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
      />
    </svg>
    """
  end

  def icon(%{name: "hero-sun"} = assigns) do
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
        d="M12 3v1.5m0 15V21m7.5-9H21m-15 0H3m14.303 5.303 1.06 1.06M5.637 5.637l1.06 1.06m10.606-1.06-1.06 1.06M5.637 18.363l1.06-1.06M15.75 12a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0Z"
      />
    </svg>
    """
  end

  def icon(%{name: "hero-moon"} = assigns) do
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
        d="M21.752 15.002A9.718 9.718 0 0 1 18 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.313.26-2.566.732-3.709a9.75 9.75 0 1 0 12.77 12.71Z"
      />
    </svg>
    """
  end

  def icon(%{name: "hero-envelope"} = assigns) do
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
        d="M21.75 7.5v9a2.25 2.25 0 0 1-2.25 2.25h-15A2.25 2.25 0 0 1 2.25 16.5v-9m19.5 0A2.25 2.25 0 0 0 19.5 5.25h-15A2.25 2.25 0 0 0 2.25 7.5m19.5 0v.243a2.25 2.25 0 0 1-1.07 1.916l-7.5 4.615a2.25 2.25 0 0 1-2.36 0l-7.5-4.615A2.25 2.25 0 0 1 2.25 7.743V7.5"
      />
    </svg>
    """
  end

  def icon(%{name: "hero-paper-airplane"} = assigns) do
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
        d="M6 12 3.27 3.125A59.77 59.77 0 0 1 21.485 12 59.77 59.77 0 0 1 3.27 20.875L6 12Zm0 0h7.5"
      />
    </svg>
    """
  end

  def icon(assigns) do
    ~H"""
    <span class={["inline-block", @class]} title={@name}>•</span>
    """
  end

  @doc """
  Renders Markdown as sanitized HTML (for trusted-ish sources such as API-generated reports).
  """
  attr :content, :string, required: true
  attr :class, :string, default: nil

  def safe_markdown(assigns) do
    html = BarragensptWeb.Markdown.to_safe_html(assigns.content)
    assigns = assign(assigns, :html, html)

    ~H"""
    <div class={["markdown-report max-w-none", @class]}>
      {Phoenix.HTML.raw(@html)}
    </div>
    """
  end

  defp normalize_date_input_value(%NaiveDateTime{} = ndt) do
    ndt |> NaiveDateTime.to_date() |> Date.to_iso8601()
  end

  defp normalize_date_input_value(%Date{} = d), do: Date.to_iso8601(d)

  defp normalize_date_input_value(s) when is_binary(s) do
    s
    |> String.trim()
    |> String.split(~r/[T ]/, parts: 2)
    |> List.first()
  end

  defp normalize_date_input_value(nil), do: nil
  defp normalize_date_input_value(_), do: nil

  defp translate_field_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end
