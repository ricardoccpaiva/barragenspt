defmodule Barragenspt.Accounts.UserNotifier do
  import Swoosh.Email

  alias Barragenspt.Mailer
  alias Barragenspt.Accounts.User
  alias Barragenspt.Notifications.UserNotification
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

  defp deliver_html(recipient, subject, html_body, text_body) do
    email =
      new()
      |> to(recipient)
      |> from({"Barragenspt", "contact@barragens.pt"})
      |> subject(subject)
      |> html_body(html_body)
      |> text_body(text_body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Instruções para atualizar o e-mail", """

    ==============================

    Olá #{user.email},

    Podes alterar o teu e-mail através do link abaixo:

    #{url}

    Se não pediste esta alteração, ignora este e-mail.

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
    deliver(user.email, "Instruções para iniciar sessão", """

    ==============================

    Olá #{user.email},

    Podes iniciar sessão na tua conta através do link abaixo:

    #{url}

    Se não pediste este e-mail, ignora-o.

    ==============================
    """)
  end

  def deliver_confirmation_instructions(user, url) do
    recipient = user.email

    deliver_html(
      recipient,
      "Confirma a tua conta Barragens.pt",
      auth_email_html(
        preheader: "Confirma a tua conta para começares a usar o Barragens.pt.",
        eyebrow: "Confirmação de conta",
        title: "Confirma o teu e-mail",
        intro: "Estás a um clique de ativar a tua conta Barragens.pt e aceder ao dashboard.",
        button_label: "Confirmar conta",
        button_url: url,
        note: "Se o botão não funcionar, copia e cola este link no teu browser:",
        raw_url: url,
        footer: "Se não criaste esta conta, podes ignorar este e-mail em segurança."
      ),
      """
      Confirma a tua conta Barragens.pt

      Olá #{recipient},

      Confirma a tua conta abrindo o link abaixo:

      #{url}

      Se não criaste esta conta, podes ignorar este e-mail em segurança.
      """
    )
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    recipient = user.email

    deliver_html(
      recipient,
      "Redefine a tua palavra-passe Barragens.pt",
      auth_email_html(
        preheader: "Recebemos um pedido para redefinir a tua palavra-passe.",
        eyebrow: "Recuperação de palavra-passe",
        title: "Redefine a tua palavra-passe",
        intro:
          "Se foste tu que pediste uma nova palavra-passe, usa o botão abaixo para escolher outra.",
        button_label: "Redefinir palavra-passe",
        button_url: url,
        note: "Se o botão não funcionar, copia e cola este link no teu browser:",
        raw_url: url,
        footer: "Se não pediste esta alteração, podes ignorar este e-mail em segurança."
      ),
      """
      Redefine a tua palavra-passe Barragens.pt

      Olá #{recipient},

      Recebemos um pedido para redefinir a tua palavra-passe.

      Usa este link para escolher uma nova:

      #{url}

      Se não pediste esta alteração, podes ignorar este e-mail em segurança.
      """
    )
  end

  @doc """
  Email when a user alert condition is met (storage / change thresholds).
  """
  def deliver_alert_triggered(
        %User{} = user,
        %UserNotification{} = alert,
        value,
        triggered_at \\ DateTime.utc_now()
      )
      when is_number(value) do
    base = BarragensptWeb.Endpoint.url()
    path = "#{base}/dashboard/notifications"
    subject = "Alerta: #{alert.subject_name} — #{format_alert_label(alert)}"
    value_str = format_value_for_email(alert.metric, value)
    triggered_at_str = format_triggered_at_pt(triggered_at)
    {triggered_date, triggered_time} = split_triggered_at(triggered_at_str)

    if alert.metric == "infoagua_alert_level" do
      deliver_flood_triggered_email(user.email, subject, path, alert, value_str, triggered_at_str)
    else
      template_variables = %{
        brand_name: "barragens.pt",
        alert_title: "Alerta disparado",
        alert_message: "Uma condição configurada por si foi cumprida em #{triggered_at_str}.",
        subject_name: alert.subject_name,
        subject_type: subject_type_pt(alert.subject_type),
        condition_text: describe_condition(alert),
        current_value: value_str,
        reading_date_label: "Data da leitura",
        reading_date: triggered_date,
        reading_time_label: "Hora da leitura",
        reading_time: triggered_time,
        triggered_at: triggered_at_str,
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
  end

  defp deliver_flood_triggered_email(recipient, subject, path, alert, value_str, triggered_at_str) do
    email =
      new()
      |> to(recipient)
      |> from({"Barragenspt", "contact@barragens.pt"})
      |> subject(subject)
      |> html_body("""
      <div style="font-family:Arial,sans-serif;max-width:680px;margin:0 auto;color:#0f172a;">
        <h1 style="font-size:38px;line-height:1.1;margin:0 0 18px;">Alerta disparado</h1>
        <p style="font-size:16px;line-height:1.5;color:#475569;margin:0 0 22px;">
          Foi detetada uma situação de cheia com estado de alerta ou risco.
        </p>
        <table style="width:100%;border-collapse:collapse;font-size:16px;">
          <tr><td style="padding:8px 0;color:#64748b;">Alvo</td><td style="padding:8px 0;font-weight:700;">#{escape_html(alert.subject_name)}</td></tr>
          <tr><td style="padding:8px 0;color:#64748b;">Tipo</td><td style="padding:8px 0;font-weight:700;">#{escape_html(subject_type_pt(alert.subject_type))}</td></tr>
          <tr><td style="padding:8px 0;color:#64748b;">Data da leitura</td><td style="padding:8px 0;font-weight:700;">#{escape_html(triggered_at_str)}</td></tr>
          <tr><td style="padding:8px 0;color:#64748b;">Estado atual</td><td style="padding:8px 0;font-weight:700;color:#166534;">#{escape_html(value_str)}</td></tr>
        </table>
        <p style="margin-top:22px;">
          <a href="#{escape_html(path)}" style="background:#0284c7;color:#fff;text-decoration:none;padding:10px 14px;border-radius:8px;display:inline-block;">Ver notificações</a>
        </p>
      </div>
      """)
      |> text_body("""
      Alerta disparado

      Alvo: #{alert.subject_name}
      Tipo: #{subject_type_pt(alert.subject_type)}
      Data da leitura: #{triggered_at_str}
      Estado atual: #{value_str}

      Ver notificações: #{path}
      """)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Telegram message when a user alert condition is met.
  """
  def deliver_alert_triggered_telegram(
        %User{} = user,
        %UserNotification{} = alert,
        value,
        triggered_at \\ DateTime.utc_now()
      )
      when is_number(value) do
    with true <- user.telegram_enabled || {:error, :telegram_disabled},
         chat_id when is_binary(chat_id) <- user.telegram_chat_id,
         chat_id when chat_id != "" <- String.trim(chat_id),
         :ok <- validate_telegram_chat_id(chat_id) do
      base = BarragensptWeb.Endpoint.url()
      path = "#{base}/dashboard/notifications"
      value_str = format_value_for_email(alert.metric, value)
      triggered_at_str = format_triggered_at_pt(triggered_at)
      {triggered_date, triggered_time} = split_triggered_at(triggered_at_str)

      condition_line =
        if alert.metric == "infoagua_alert_level" do
          ""
        else
          condition = describe_condition(alert) |> String.replace_prefix("Condição: ", "")
          "<b>Condição:</b> #{escape_html(condition)}"
        end

      text =
        [
          "<b>🚨 Alerta disparado</b>",
          "",
          "<b>Alvo:</b> #{escape_html(alert.subject_name)}",
          "<b>Data da leitura:</b> #{escape_html(triggered_date)}",
          "<b>Hora da leitura:</b> #{escape_html(triggered_time)}",
          condition_line,
          "<b>Valor atual: </b><code>#{escape_html(value_str)}</code>",
          "<a href=\"#{escape_html(path)}\">Abrir alertas no dashboard</a>"
        ]
        |> Enum.reject(&(&1 == ""))
        |> Enum.join("\n")

      telegram_client_module().send_message(chat_id, text,
        parse_mode: "HTML",
        disable_web_page_preview: true
      )
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

  defp auth_email_html(assigns) do
    """
    <!doctype html>
    <html lang="en">
      <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>#{escape_html(assigns[:title] || "Barragenspt")}</title>
      </head>
      <body style="margin:0;padding:0;background:#f8fafc;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#0f172a;">
        <div style="display:none;max-height:0;overflow:hidden;opacity:0;">
          #{escape_html(assigns[:preheader] || "")}
        </div>
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f8fafc;padding:24px 12px;">
          <tr>
            <td align="center">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:640px;">
                <tr>
                  <td style="padding-bottom:16px;text-align:left;">
                    <div style="font-size:13px;font-weight:700;letter-spacing:0.12em;text-transform:uppercase;color:#0284c7;">
                      barragens.pt
                    </div>
                  </td>
                </tr>
                <tr>
                  <td style="background:linear-gradient(135deg,#0f172a 0%,#1e3a8a 100%);border-radius:24px 24px 0 0;padding:32px 32px 24px;">
                    <div style="display:inline-block;padding:6px 12px;border-radius:999px;background:rgba(255,255,255,0.14);font-size:12px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#e0f2fe;">
                      #{escape_html(assigns[:eyebrow] || "")}
                    </div>
                    <h1 style="margin:18px 0 0;font-size:34px;line-height:1.1;font-weight:800;color:#ffffff;">
                      #{escape_html(assigns[:title] || "")}
                    </h1>
                  </td>
                </tr>
                <tr>
                  <td style="background:#ffffff;border-radius:0 0 24px 24px;padding:32px;border:1px solid #e2e8f0;border-top:none;">
                    <p style="margin:0 0 18px;font-size:16px;line-height:1.6;color:#334155;">
                      #{escape_html(assigns[:intro] || "")}
                    </p>
                    <table role="presentation" cellspacing="0" cellpadding="0" style="margin:0 0 24px;">
                      <tr>
                        <td>
                          <a href="#{escape_html(assigns[:button_url] || "#")}" style="display:inline-block;padding:14px 22px;border-radius:12px;background:#0284c7;color:#ffffff;text-decoration:none;font-size:15px;font-weight:700;">
                            #{escape_html(assigns[:button_label] || "Open")}
                          </a>
                        </td>
                      </tr>
                    </table>
                    <div style="margin:0 0 24px;padding:18px 20px;border-radius:16px;background:#f8fafc;border:1px solid #e2e8f0;">
                      <p style="margin:0 0 10px;font-size:13px;font-weight:700;text-transform:uppercase;letter-spacing:0.06em;color:#64748b;">
                        Link alternativo
                      </p>
                      <p style="margin:0 0 10px;font-size:14px;line-height:1.6;color:#475569;">
                        #{escape_html(assigns[:note] || "")}
                      </p>
                      <p style="margin:0;word-break:break-all;">
                        <a href="#{escape_html(assigns[:raw_url] || "#")}" style="font-size:14px;line-height:1.6;color:#0284c7;text-decoration:none;">
                          #{escape_html(assigns[:raw_url] || "")}
                        </a>
                      </p>
                    </div>
                    <p style="margin:0;font-size:14px;line-height:1.6;color:#64748b;">
                      #{escape_html(assigns[:footer] || "")}
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </body>
    </html>
    """
  end

  defp validate_telegram_chat_id(chat_id) do
    if Regex.match?(~r/^-?\d+$/, chat_id) do
      :ok
    else
      {:error, :telegram_chat_id_invalid}
    end
  end

  defp escape_html(v) when is_binary(v) do
    v
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp escape_html(v), do: v |> to_string() |> escape_html()

  defp describe_condition(%UserNotification{} = a) do
    if a.metric == "infoagua_alert_level" do
      "Condição: InfoÁgua em Situação de alerta ou Situação de risco."
    else
      op = if a.operator == "lt", do: "inferior a", else: "superior a"
      metric = condition_metric_label(a.metric)
      "Condição: #{metric} #{op} #{threshold_with_unit(a.metric, a.threshold)}"
    end
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
  defp format_metric("infoagua_alert_level"), do: "Nível de alerta de cheia (InfoÁgua)"
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
  defp condition_metric_label("infoagua_alert_level"), do: "Nível de alerta de cheia"
  defp condition_metric_label(metric), do: format_metric(metric)

  defp subject_type_pt("dam"), do: "Barragem"
  defp subject_type_pt("basin"), do: "Bacia"
  defp subject_type_pt(other), do: to_string(other)

  defp format_triggered_at_pt(%DateTime{} = dt) do
    dt
    |> DateTime.shift_zone!("Europe/Lisbon")
    |> Calendar.strftime("%d/%m/%Y %H:%M")
  end

  defp split_triggered_at(triggered_at_str) do
    case String.split(triggered_at_str, " ", parts: 2) do
      [date, time] -> {date, time}
      [date] -> {date, ""}
      _ -> {triggered_at_str, ""}
    end
  end

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

  defp format_value_for_email("infoagua_alert_level", value) do
    infoagua_level_label(value)
  end

  defp format_value_for_email(_metric, value) do
    to_string(Float.round(value * 1.0, 2))
  end

  defp format_alert_label(%UserNotification{metric: m, operator: op, threshold: t}) do
    if m == "infoagua_alert_level" do
      "InfoÁgua: Situação de alerta/risco"
    else
      o = if op == "lt", do: "<", else: ">"
      "#{condition_metric_label(m)} #{o} #{threshold_with_unit(m, t)}"
    end
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
  defp threshold_with_unit("infoagua_alert_level", threshold), do: "#{threshold} (0-3)"
  defp threshold_with_unit(_, threshold), do: to_string(threshold)

  defp infoagua_level_label(v) when is_number(v) do
    cond do
      v >= 2 -> "Situação de risco"
      v >= 1 -> "Situação de alerta"
      true -> "Sem alertas ativos"
    end
  end
end
