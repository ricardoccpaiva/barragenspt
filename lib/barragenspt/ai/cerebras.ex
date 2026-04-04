defmodule Barragenspt.Ai.Cerebras do
  @moduledoc """
  OpenAI-compatible chat completions against Cerebras Inference API.

  Config (via `config/runtime.exs`): `:cerebras_api_key`, `:cerebras_base_url`, `:cerebras_model`.
  """

  @default_timeout_ms 120_000

  @type message :: %{String.t() => String.t()} | %{role: String.t(), content: String.t()}

  @spec configured?() :: boolean()
  def configured? do
    case api_key() do
      k when is_binary(k) and k != "" -> true
      _ -> false
    end
  end

  @spec chat_completion([message()], keyword()) :: {:ok, String.t()} | {:error, term()}
  def chat_completion(messages, opts \\ []) when is_list(messages) do
    with {:ok, key} <- fetch_api_key(),
         {:ok, model} <- fetch_model() do
      payload = %{
        "model" => model,
        "messages" => normalize_messages(messages),
        "temperature" => Keyword.get(opts, :temperature, 0.35),
        "max_tokens" => Keyword.get(opts, :max_tokens, 4096)
      }

      key
      |> client(Keyword.get(opts, :timeout_ms, @default_timeout_ms))
      |> Tesla.post("/chat/completions", payload)
      |> parse_chat_response()
    end
  end

  @doc false
  @spec content_from_response_body(map()) :: {:ok, String.t()} | {:error, term()}
  def content_from_response_body(body) when is_map(body) do
    case get_in(body, ["choices", Access.at(0), "message", "content"]) do
      content when is_binary(content) -> {:ok, String.trim(content)}
      _ -> {:error, {:cerebras_unexpected_body, body}}
    end
  end

  defp fetch_api_key do
    case api_key() do
      k when is_binary(k) and k != "" -> {:ok, k}
      _ -> {:error, :cerebras_api_key_missing}
    end
  end

  defp fetch_model do
    case model() do
      m when is_binary(m) and m != "" -> {:ok, m}
      _ -> {:error, :cerebras_model_missing}
    end
  end

  defp api_key, do: Application.get_env(:barragenspt, :cerebras_api_key)

  defp model, do: Application.get_env(:barragenspt, :cerebras_model)

  defp base_url do
    Application.get_env(:barragenspt, :cerebras_base_url, "https://api.cerebras.ai/v1")
    |> to_string()
    |> String.trim_trailing("/")
  end

  defp normalize_messages(messages) do
    Enum.map(messages, fn
      %{"role" => r, "content" => c} -> %{"role" => r, "content" => c}
      %{role: r, content: c} -> %{"role" => to_string(r), "content" => to_string(c)}
    end)
  end

  defp client(api_key, timeout_ms) do
    middleware = [
      {Tesla.Middleware.BaseUrl, base_url()},
      {Tesla.Middleware.Headers,
       [
         {"authorization", "Bearer #{api_key}"},
         {"content-type", "application/json"}
       ]},
      {Tesla.Middleware.Timeout, timeout: timeout_ms},
      Tesla.Middleware.JSON
    ]

    Tesla.client(middleware)
  end

  defp parse_chat_response({:ok, %Tesla.Env{status: status, body: body}})
       when status in 200..299 and is_map(body) do
    content_from_response_body(body)
  end

  defp parse_chat_response({:ok, %Tesla.Env{status: status, body: body}}) do
    {:error, {:cerebras_http_error, status, body}}
  end

  defp parse_chat_response({:error, %Tesla.Error{reason: reason}}) do
    {:error, {:cerebras_transport, reason}}
  end

  defp parse_chat_response({:error, reason}), do: {:error, {:cerebras_transport, reason}}
end
