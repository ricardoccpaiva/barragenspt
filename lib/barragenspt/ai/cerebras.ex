defmodule Barragenspt.Ai.Cerebras do
  @moduledoc """
  Simple OpenAI-compatible chat completion client for Cerebras.
  """

  @type message :: %{role: String.t(), content: String.t()}

  @spec configured?() :: boolean()
  def configured? do
    present?(api_key()) and present?(model())
  end

  @spec chat_completion([message()]) :: {:ok, String.t()} | {:error, term()}
  def chat_completion(messages) when is_list(messages) do
    with {:ok, api_key} <- fetch_api_key(),
         {:ok, model} <- fetch_model(),
         payload <- %{model: model, messages: messages},
         {:ok, response} <- request(api_key, payload) do
      parse_chat_response(response)
    end
  end

  defp fetch_api_key do
    case api_key() do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, :cerebras_api_key_missing}
    end
  end

  defp fetch_model do
    case model() do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, :cerebras_model_missing}
    end
  end

  defp request(api_key, payload) do
    headers = [
      {"authorization", "Bearer " <> api_key},
      {"content-type", "application/json"}
    ]

    client =
      Tesla.client([
        {Tesla.Middleware.BaseUrl, base_url()},
        Tesla.Middleware.JSON,
        {Tesla.Middleware.Headers, headers}
      ])

    case Tesla.post(client, "/chat/completions", payload) do
      {:ok, %Tesla.Env{status: status} = env} when status in 200..299 ->
        {:ok, env.body}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, {:cerebras_http_error, status, body}}

      {:error, reason} ->
        {:error, {:cerebras_transport, reason}}
    end
  end

  defp parse_chat_response(%{"choices" => [%{"message" => %{"content" => content}} | _]})
       when is_binary(content) do
    {:ok, String.trim(content)}
  end

  defp parse_chat_response(body), do: {:error, {:cerebras_unexpected_body, body}}

  defp api_key, do: Application.get_env(:barragenspt, :cerebras_api_key)
  defp model, do: Application.get_env(:barragenspt, :cerebras_model)

  defp base_url do
    Application.get_env(:barragenspt, :cerebras_base_url, "https://api.cerebras.ai/v1")
    |> to_string()
    |> String.trim_trailing("/")
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_), do: false
end
