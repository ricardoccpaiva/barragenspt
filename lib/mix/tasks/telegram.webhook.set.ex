defmodule Mix.Tasks.Telegram.Webhook.Set do
  use Mix.Task

  alias Barragenspt.Notifications.TelegramClient

  @shortdoc "Configure Telegram webhook interactively"

  @moduledoc """
  Configures Telegram webhook by prompting for:

  - Public webhook URL
  - Webhook secret token
  - Bot token

  Usage:

      mix telegram.webhook.set
  """

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    shell = Mix.shell()

    shell.info("\nTelegram webhook setup\n")

    url =
      prompt_required(
        shell,
        "Webhook URL (e.g. https://your-domain.com/telegram/webhook): "
      )

    secret_token =
      prompt_required(
        shell,
        "Webhook secret token (must match TELEGRAM_WEBHOOK_SECRET): "
      )

    bot_token =
      prompt_required(
        shell,
        "Bot token (from @BotFather): "
      )

    shell.info("\nSetting webhook...")

    with {:ok, set_resp} <- TelegramClient.set_webhook(bot_token, url, secret_token),
         {:ok, info_resp} <- TelegramClient.get_webhook_info(bot_token) do
      shell.info("Webhook configured successfully.")
      shell.info("Telegram response: #{inspect(set_resp["result"] || set_resp)}")
      shell.info("Webhook info: #{inspect(info_resp["result"] || info_resp)}")
    else
      {:error, reason} ->
        shell.error("Failed to configure webhook: #{inspect(reason)}")
        Mix.raise("telegram.webhook.set failed")
    end
  end

  defp prompt_required(shell, prompt) do
    prompt
    |> shell.prompt()
    |> to_string()
    |> String.trim()
    |> case do
      "" -> Mix.raise("Missing required value for: #{String.trim(prompt)}")
      value -> value
    end
  end
end
