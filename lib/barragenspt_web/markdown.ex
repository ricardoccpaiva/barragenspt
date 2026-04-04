defmodule BarragensptWeb.Markdown do
  @moduledoc """
  Converts Markdown to HTML and sanitizes it for safe embedding (e.g. LLM output).
  """

  @doc """
  Returns HTML safe for `Phoenix.HTML.raw/1` after passing through an HTML5 sanitizer.
  """
  @spec to_safe_html(String.t() | nil) :: String.t()
  def to_safe_html(nil), do: ""

  def to_safe_html(text) when is_binary(text) do
    ensure_markdown_apps!()

    text = String.trim(text)

    if text == "" do
      ""
    else
      case Earmark.as_html(text) do
        {:ok, html, _} -> HtmlSanitizeEx.html5(html)
        _ -> escaped_fallback(text)
      end
    end
  end

  defp ensure_markdown_apps! do
    {:ok, _} = Application.ensure_all_started(:earmark)
    {:ok, _} = Application.ensure_all_started(:html_sanitize_ex)
  end

  defp escaped_fallback(text) do
    text
    |> Plug.HTML.html_escape()
    |> IO.iodata_to_binary()
  end
end
