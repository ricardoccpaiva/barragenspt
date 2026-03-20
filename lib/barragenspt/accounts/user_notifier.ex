defmodule Barragenspt.Accounts.UserNotifier do
  import Swoosh.Email

  alias Barragenspt.Mailer
  alias Barragenspt.Accounts.User
  alias Barragenspt.Notifications.UserAlert

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Barragenspt", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  # Delivers multipart email (text + HTML) for richer notifications.
  defp deliver_with_html(recipient, subject, text, html) do
    email =
      new()
      |> to(recipient)
      |> from({"Barragenspt", "contact@example.com"})
      |> subject(subject)
      |> text_body(text)
      |> html_body(html)

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
    text_body = """

    ==============================

    Foi disparado um alerta configurado em barragens.pt.

    Alvo: #{alert.subject_name} (#{subject_type_pt(alert.subject_type)})
    #{condition}
    Valor atual: #{value_str}

    Gerir os seus alertas: #{path}

    ==============================
    """

    html_body = """
    <div style="margin:0;padding:24px;background:#f8fafc;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#0f172a;">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:620px;margin:0 auto;">
        <tr>
          <td style="padding:0 0 14px 0;">
            <div style="font-size:22px;font-weight:700;color:#0369a1;">barragens.pt</div>
          </td>
        </tr>
        <tr>
          <td style="background:#ffffff;border:1px solid #e2e8f0;border-radius:14px;padding:24px;">
            <div style="font-size:18px;font-weight:700;color:#111827;margin-bottom:6px;">Alerta disparado</div>
            <div style="font-size:14px;line-height:1.6;color:#475569;margin-bottom:18px;">
              Uma condição configurada por si foi cumprida.
            </div>

            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:separate;border-spacing:0 8px;">
              <tr>
                <td style="font-size:13px;color:#64748b;width:140px;">Alvo</td>
                <td style="font-size:14px;font-weight:600;color:#0f172a;">#{alert.subject_name}</td>
              </tr>
              <tr>
                <td style="font-size:13px;color:#64748b;">Tipo</td>
                <td style="font-size:14px;color:#0f172a;">#{subject_type_pt(alert.subject_type)}</td>
              </tr>
              <tr>
                <td style="font-size:13px;color:#64748b;">Condição</td>
                <td style="font-size:14px;color:#0f172a;">#{condition}</td>
              </tr>
              <tr>
                <td style="font-size:13px;color:#64748b;">Valor atual</td>
                <td style="font-size:16px;font-weight:700;color:#166534;">#{value_str}</td>
              </tr>
            </table>

            <div style="margin-top:24px;">
              <a href="#{path}" style="display:inline-block;background:#0284c7;color:#ffffff;text-decoration:none;font-weight:600;font-size:14px;padding:11px 16px;border-radius:10px;">
                Ver alertas
              </a>
            </div>
          </td>
        </tr>
        <tr>
          <td style="padding:14px 2px 0 2px;font-size:12px;color:#64748b;">
            Está a receber este e-mail porque tem alertas ativos na sua conta.
          </td>
        </tr>
      </table>
    </div>
    """

    deliver_with_html(user.email, subject, text_body, html_body)
  end

  defp describe_condition(%UserAlert{} = a) do
    op = if a.operator == "lt", do: "inferior a", else: "superior a"
    metric = format_metric(a.metric)
    "Condição: #{metric} #{op} #{a.threshold}"
  end

  defp format_metric("storage_pct"), do: "Ocupação (%)"
  defp format_metric("month_change_pct"), do: "Variação vs 1 mês (p.p.)"
  defp format_metric("year_change_pct"), do: "Variação vs 1 ano (p.p.)"
  defp format_metric(_), do: "Indicador"

  defp subject_type_pt("dam"), do: "Barragem"
  defp subject_type_pt("basin"), do: "Bacia"
  defp subject_type_pt("national"), do: "Nacional"
  defp subject_type_pt(other), do: to_string(other)

  defp format_value_for_email("storage_pct", value) do
    "#{Float.round(value * 1.0, 1)}%"
  end

  defp format_value_for_email(metric, value) when metric in ["month_change_pct", "year_change_pct"] do
    "#{Float.round(value * 1.0, 2)} p.p."
  end

  defp format_value_for_email(_metric, value) do
    to_string(Float.round(value * 1.0, 2))
  end

  defp format_alert_label(%UserAlert{metric: m, operator: op, threshold: t}) do
    o = if op == "lt", do: "<", else: ">"
    "#{format_metric(m)} #{o} #{t}"
  end
end
