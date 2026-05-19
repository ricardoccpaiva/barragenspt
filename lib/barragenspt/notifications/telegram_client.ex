defmodule Barragenspt.Notifications.TelegramClient do
  @moduledoc """
  Thin client for Telegram Bot API message delivery.
  """

  @type send_result :: {:ok, map()} | {:error, term()}
  @type api_result :: {:ok, map()} | {:error, term()}

  @spec send_message(String.t(), String.t(), keyword()) :: send_result
  def send_message(chat_id, text, opts \\ [])
      when is_binary(chat_id) and is_binary(text) and is_list(opts) do
    with {:ok, token} <- fetch_token() do
      send_message_with_token(token, chat_id, text, opts)
    end
  end

  @spec send_message_with_token(String.t(), String.t(), String.t(), keyword()) :: send_result
  def send_message_with_token(token, chat_id, text, opts \\ [])
      when is_binary(token) and is_binary(chat_id) and is_binary(text) and is_list(opts) do
    with {:ok, payload} <- build_payload(chat_id, text, opts) do
      token
      |> client()
      |> Tesla.post("/sendMessage", payload)
      |> parse_response()
    end
  end

  @spec set_webhook(String.t(), String.t(), String.t() | nil) :: api_result
  def set_webhook(token, url, secret_token \\ nil)
      when is_binary(token) and is_binary(url) do
    payload =
      if is_binary(secret_token) and String.trim(secret_token) != "" do
        %{"url" => url, "secret_token" => secret_token}
      else
        %{"url" => url}
      end

    token
    |> client()
    |> Tesla.post("/setWebhook", payload)
    |> parse_response()
  end

  @spec get_webhook_info(String.t()) :: api_result
  def get_webhook_info(token) when is_binary(token) do
    token
    |> client()
    |> Tesla.get("/getWebhookInfo")
    |> parse_response()
  end

  defp fetch_token do
    case Application.get_env(:barragenspt, :telegram_bot_token) do
      token when is_binary(token) and token != "" -> {:ok, token}
      _ -> {:error, :telegram_bot_token_missing}
    end
  end

  defp build_payload(chat_id, text, opts) do
    parse_mode = Keyword.get(opts, :parse_mode)
    disable_preview = Keyword.get(opts, :disable_web_page_preview, true)

    payload = %{
      "chat_id" => chat_id,
      "text" => text,
      "disable_web_page_preview" => disable_preview
    }

    payload =
      if is_binary(parse_mode) and parse_mode != "" do
        Map.put(payload, "parse_mode", parse_mode)
      else
        payload
      end

    {:ok, payload}
  end

  defp client(token) do
    middleware = [
      {Tesla.Middleware.BaseUrl, "https://api.telegram.org/bot#{token}"},
      Tesla.Middleware.JSON
    ]

    Tesla.client(middleware)
  end

  defp parse_response({:ok, %Tesla.Env{status: status, body: %{"ok" => true} = body}})
       when status in 200..299 do
    {:ok, body}
  end

  defp parse_response({:ok, %Tesla.Env{status: status, body: body}}) do
    {:error, {:telegram_http_error, status, body}}
  end

  defp parse_response({:error, reason}), do: {:error, reason}
end
