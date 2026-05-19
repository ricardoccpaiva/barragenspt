defmodule BarragensptWeb.TelegramWebhookController do
  use BarragensptWeb, :controller

  require Logger

  alias Barragenspt.Accounts

  def create(conn, params) do
    if valid_secret?(conn) do
      maybe_consume_start_link(params)
      json(conn, %{ok: true})
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{ok: false, error: "unauthorized"})
    end
  end

  defp maybe_consume_start_link(params) do
    text = get_in(params, ["message", "text"])
    chat_id = get_in(params, ["message", "chat", "id"])

    with true <- is_binary(text),
         true <- String.starts_with?(text, "/start"),
         token when is_binary(token) <- start_token(text),
         true <- token != "",
         true <- not is_nil(chat_id) do
      case Accounts.consume_telegram_link_token(token, to_string(chat_id)) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          Logger.warning("Telegram webhook: failed to consume link token: #{inspect(reason)}")
      end
    else
      _ -> :ok
    end
  end

  defp start_token(text) do
    case String.split(text, ~r/\s+/, trim: true) do
      [command, token | _] when is_binary(command) -> token
      _ -> nil
    end
  end

  defp valid_secret?(conn) do
    expected = Application.get_env(:barragenspt, :telegram_webhook_secret)

    if blank?(expected) do
      true
    else
      header = List.first(get_req_header(conn, "x-telegram-bot-api-secret-token"))

      if is_binary(header) and byte_size(header) == byte_size(expected) do
        Plug.Crypto.secure_compare(header, expected)
      else
        false
      end
    end
  end

  defp blank?(v), do: is_nil(v) or (is_binary(v) and String.trim(v) == "")
end
