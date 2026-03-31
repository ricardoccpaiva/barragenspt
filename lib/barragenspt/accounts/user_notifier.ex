defmodule Barragenspt.Accounts.UserNotifier do
  import Swoosh.Email

  alias Barragenspt.Mailer
  alias Barragenspt.Accounts.User
  alias Barragenspt.Notifications.UserAlert
  alias Barragenspt.Notifications.TelegramClient
  alias Resend.Emails.Email

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Barragenspt", "contact@barragens.pt"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(user.email, "Log in instructions", """

    ==============================

    Hi #{user.email},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Email when a user alert condition is met (storage / change thresholds).
  """
  def deliver_alert_triggered(%User{} = user, %UserAlert{} = alert, value)
      when is_number(value) do
    base = BarragensptWeb.Endpoint.url()
    path = "#{base}/dashboard/alerts"
    subject = "Alerta: #{alert.subject_name} — #{format_alert_label(alert)}"
    condition = describe_condition(alert)
    value_str = format_value_for_email(alert.metric, value)

    template_variables = %{
      brand_name: "barragens.pt",
      alert_title: "Alerta disparado",
      alert_message: "Uma condição configurada por si foi cumprida.",
      subject_name: alert.subject_name,
      subject_type: subject_type_pt(alert.subject_type),
      condition_text: condition,
      current_value: value_str,
      alerts_url: path,
      footer_text: "Está a receber este e-mail porque tem alertas ativos na sua conta."
    }

    deliver_resend_template(
      user.email,
      subject,
      "alert-notification",
      template_variables
    )
  end

  @doc """
  Telegram message when a user alert condition is met.
  """
  def deliver_alert_triggered_telegram(%User{} = user, %UserAlert{} = alert, value)
      when is_number(value) do
    with true <- user.telegram_enabled || {:error, :telegram_disabled},
         chat_id when is_binary(chat_id) <- user.telegram_chat_id,
         chat_id when chat_id != "" <- String.trim(chat_id),
         :ok <- validate_telegram_chat_id(chat_id) do
      base = BarragensptWeb.Endpoint.url()
      path = "#{base}/dashboard/alerts"
      condition = describe_condition(alert)
      value_str = format_value_for_email(alert.metric, value)

      text = """
      Alerta disparado
      Alvo: #{alert.subject_name}
      #{condition}
      Valor atual: #{value_str}
      Ver alertas: #{path}
      """

      telegram_client_module().send_message(chat_id, text)
    else
      false -> {:error, :telegram_disabled}
      nil -> {:error, :telegram_chat_id_missing}
      "" -> {:error, :telegram_chat_id_missing}
      {:error, _} = error -> error
    end
  end

  defp deliver_resend_template(recipient, subject, template_id, template_variables) do
    case Application.get_env(:barragenspt, :resend_api_key) do
      nil ->
        {:error, :resend_api_key_missing}

      api_key ->
        client = Resend.client(api_key: api_key)

        Resend.Client.post(client, Email, "/emails", %{
          from: "Barragenspt <contact@barragens.pt>",
          to: [recipient],
          subject: subject,
          template: %{
            id: template_id,
            variables: template_variables
          }
        })
    end
  end

  defp telegram_client_module do
    Application.get_env(:barragenspt, :telegram_client_module, TelegramClient)
  end

  defp validate_telegram_chat_id(chat_id) do
    if Regex.match?(~r/^-?\d+$/, chat_id) do
      :ok
    else
      {:error, :telegram_chat_id_invalid}
    end
  end

  defp describe_condition(%UserAlert{} = a) do
    op = if a.operator == "lt", do: "inferior a", else: "superior a"
    metric = condition_metric_label(a.metric)
    "Condição: #{metric} #{op} #{threshold_with_unit(a.metric, a.threshold)}"
  end

  defp format_metric("storage_pct"), do: "Ocupação (%)"
  defp format_metric("month_change_pct"), do: "Variação vs 1 mês (p.p.)"
  defp format_metric("year_change_pct"), do: "Variação vs 1 ano (p.p.)"
  defp format_metric("realtime_level"), do: "Cota (m, realtime)"
  defp format_metric("realtime_inflow"), do: "Caudal afluente (m3/s, realtime)"
  defp format_metric("realtime_outflow"), do: "Caudal efluente (m3/s, realtime)"
  defp format_metric("realtime_storage"), do: "Volume armazenado (%, realtime)"
  defp format_metric("daily_discharged_flow"), do: "Caudal descarregado médio diário (m3/s)"
  defp format_metric("daily_tributary_flow"), do: "Caudal afluente médio diário (m3/s)"
  defp format_metric("daily_effluent_flow"), do: "Caudal efluente médio diário (m3/s)"
  defp format_metric("daily_turbocharged_flow"), do: "Caudal turbinado médio diário (m3/s)"
  defp format_metric(_), do: "Indicador"

  defp condition_metric_label("storage_pct"), do: "Ocupação"
  defp condition_metric_label("month_change_pct"), do: "Variação vs 1 mês"
  defp condition_metric_label("year_change_pct"), do: "Variação vs 1 ano"
  defp condition_metric_label("realtime_level"), do: "Cota (realtime)"
  defp condition_metric_label("realtime_inflow"), do: "Caudal afluente (realtime)"
  defp condition_metric_label("realtime_outflow"), do: "Caudal efluente (realtime)"
  defp condition_metric_label("realtime_storage"), do: "Volume armazenado (realtime)"
  defp condition_metric_label("daily_discharged_flow"), do: "Caudal descarregado médio diário"
  defp condition_metric_label("daily_tributary_flow"), do: "Caudal afluente médio diário"
  defp condition_metric_label("daily_effluent_flow"), do: "Caudal efluente médio diário"
  defp condition_metric_label("daily_turbocharged_flow"), do: "Caudal turbinado médio diário"
  defp condition_metric_label(metric), do: format_metric(metric)

  defp subject_type_pt("dam"), do: "Barragem"
  defp subject_type_pt(other), do: to_string(other)

  defp format_value_for_email("storage_pct", value) do
    "#{Float.round(value * 1.0, 1)}%"
  end

  defp format_value_for_email(metric, value)
       when metric in ["month_change_pct", "year_change_pct"] do
    "#{Float.round(value * 1.0, 2)} p.p."
  end

  defp format_value_for_email("realtime_level", value) do
    "#{Float.round(value * 1.0, 2)} m"
  end

  defp format_value_for_email(metric, value)
       when metric in [
              "realtime_inflow",
              "realtime_outflow",
              "daily_discharged_flow",
              "daily_tributary_flow",
              "daily_effluent_flow",
              "daily_turbocharged_flow"
            ] do
    "#{Float.round(value * 1.0, 2)} m3/s"
  end

  defp format_value_for_email("realtime_storage", value) do
    "#{Float.round(value * 1.0, 2)}%"
  end

  defp format_value_for_email(_metric, value) do
    to_string(Float.round(value * 1.0, 2))
  end

  defp format_alert_label(%UserAlert{metric: m, operator: op, threshold: t}) do
    o = if op == "lt", do: "<", else: ">"
    "#{condition_metric_label(m)} #{o} #{threshold_with_unit(m, t)}"
  end

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
  defp threshold_with_unit("month_change_pct", threshold), do: "#{threshold} p.p."
  defp threshold_with_unit("year_change_pct", threshold), do: "#{threshold} p.p."
  defp threshold_with_unit("realtime_storage", threshold), do: "#{threshold}%"
  defp threshold_with_unit(_, threshold), do: to_string(threshold)
end
