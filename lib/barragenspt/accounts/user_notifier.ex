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

    deliver(user.email, subject, """

    ==============================

    Foi disparado um alerta configurado em barragens.pt.

    Alvo: #{alert.subject_name} (#{alert.subject_type})
    #{condition}
    Valor atual: #{Float.round(value * 1.0, 1)}

    Gerir os seus alertas: #{path}

    ==============================
    """)
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

  defp format_alert_label(%UserAlert{metric: m, operator: op, threshold: t}) do
    o = if op == "lt", do: "<", else: ">"
    "#{format_metric(m)} #{o} #{t}"
  end
end
