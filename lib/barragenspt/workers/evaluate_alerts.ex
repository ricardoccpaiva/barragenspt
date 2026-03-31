defmodule Barragenspt.Workers.EvaluateAlerts do
  @moduledoc """
  Evaluates active user alerts after materialized views are fresh.
  """
  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3,
    unique: [period: 14 * 60, fields: [:worker], states: [:available, :scheduled, :executing]]

  require Logger

  import Ecto.Query

  alias Barragenspt.Repo
  alias Barragenspt.Accounts.{User, UserNotifier}
  alias Barragenspt.Notifications
  alias Barragenspt.Notifications.{UserAlert, AlertMetrics}

  @doc """
  Enqueue a full pass over active alerts (same as after a materialized-view refresh).
  `id_prefix` is stored in job args for logs (e.g. `\"navbar\"`, `\"manual\"`).
  """
  def schedule_manual(id_prefix \\ "manual") do
    %{"id" => "#{id_prefix}-#{:erlang.unique_integer([:positive])}"}
    |> new()
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{attempt: 1, args: %{"id" => job_id}}) do
    Logger.info("EvaluateAlerts starting oban_job_id=#{job_id}")

    alerts = Repo.all(from(a in UserAlert, where: a.active == true))
    Logger.info("EvaluateAlerts loaded #{length(alerts)} active alert(s)")

    Enum.each(alerts, &evaluate_alert(&1, job_id))

    Logger.info("EvaluateAlerts finished oban_job_id=#{job_id}")

    :ok
  end

  defp evaluate_alert(alert, oban_job_id) do
    user = Repo.get(User, alert.user_id)
    value = AlertMetrics.current_value(alert)
    met? = AlertMetrics.condition_met?(value, alert.operator, alert.threshold)

    Logger.debug(
      "----> EvaluateAlerts alert_id=#{alert.id} oban_job_id=#{oban_job_id} " <>
        "subject=#{inspect(alert.subject_name)} type=#{alert.subject_type} " <>
        "metric=#{alert.metric} value=#{inspect(value)} " <>
        "check=(#{alert.operator} #{inspect(alert.threshold)}) met=#{met?}"
    )

    cond do
      user == nil ->
        Logger.warning(
          "EvaluateAlerts alert_id=#{alert.id}: no user for user_id=#{alert.user_id}, skipping"
        )

      met? ->
        maybe_fire(alert, user, value, oban_job_id)

      true ->
        Notifications.clear_breach_state_if_needed(alert, false)

        Logger.debug(
          "EvaluateAlerts alert_id=#{alert.id}: condition not met, cleared breach state if needed"
        )
    end
  end

  defp maybe_fire(alert, user, value, oban_job_id) do
    should? =
      case alert.repeat_mode do
        "once_per_event" ->
          !alert.breach_notification_sent

        "cooldown" ->
          case alert.last_notified_at do
            nil -> true
            t -> DateTime.diff(DateTime.utc_now(), t, :second) >= alert.cooldown_hours * 3600
          end

        "always" ->
          true

        other ->
          Logger.warning(
            "EvaluateAlerts alert_id=#{alert.id}: unknown repeat_mode=#{inspect(other)}, will not notify"
          )

          false
      end

    if should? do
      fire(alert, user, value, oban_job_id)
    else
      Logger.debug(
        "EvaluateAlerts alert_id=#{alert.id} oban_job_id=#{oban_job_id}: " <>
          "condition met but notification suppressed " <>
          "(repeat_mode=#{alert.repeat_mode}, breach_notification_sent=#{alert.breach_notification_sent}, " <>
          "last_notified_at=#{inspect(alert.last_notified_at)}, cooldown_hours=#{alert.cooldown_hours})"
      )
    end
  end

  defp fire(alert, user, value, oban_job_id) do
    now = DateTime.utc_now()

    email_result = maybe_deliver_email(user, alert, value)
    telegram_result = maybe_deliver_telegram(user, alert, value)
    notified? = delivered?(email_result) or delivered?(telegram_result)

    log_delivery_result("email", email_result, alert, user, value, oban_job_id)
    log_delivery_result("telegram", telegram_result, alert, user, value, oban_job_id)

    if notified? do
      Notifications.create_event!(%{
        alert_id: alert.id,
        triggered_at: now,
        value_at_trigger: value,
        notified: true
      })

      attrs =
        if alert.repeat_mode == "once_per_event" do
          %{breach_notification_sent: true, last_notified_at: now}
        else
          %{last_notified_at: now}
        end

      Notifications.update_after_notification(alert, attrs)
    else
      Logger.warning(
        "EvaluateAlerts alert_id=#{alert.id} oban_job_id=#{oban_job_id}: all notification channels failed"
      )
    end
  end

  defp maybe_deliver_email(user, alert, value) do
    if user_email_notifications_enabled?(user) do
      UserNotifier.deliver_alert_triggered(user, alert, value)
    else
      {:skipped, :email_disabled}
    end
  end

  defp maybe_deliver_telegram(user, alert, value) do
    if user.telegram_enabled do
      UserNotifier.deliver_alert_triggered_telegram(user, alert, value)
    else
      {:skipped, :telegram_disabled}
    end
  end

  defp user_email_notifications_enabled?(user),
    do: Map.get(user, :email_notifications_enabled, true) != false

  defp delivered?({:ok, _}), do: true
  defp delivered?(_), do: false

  defp log_delivery_result(channel, {:ok, _}, alert, user, value, oban_job_id) do
    Logger.info(
      "EvaluateAlerts alert_id=#{alert.id} oban_job_id=#{oban_job_id} " <>
        "user_id=#{user.id}: #{channel} sent for triggered alert value=#{inspect(value)}"
    )
  end

  defp log_delivery_result(channel, {:skipped, reason}, alert, user, _value, oban_job_id) do
    Logger.debug(
      "EvaluateAlerts alert_id=#{alert.id} oban_job_id=#{oban_job_id} " <>
        "user_id=#{user.id}: #{channel} skipped #{inspect(reason)}"
    )
  end

  defp log_delivery_result(channel, {:error, reason}, alert, user, _value, oban_job_id) do
    Logger.warning(
      "EvaluateAlerts alert_id=#{alert.id} oban_job_id=#{oban_job_id} " <>
        "user_id=#{user.id}: #{channel} failed #{inspect(reason)}"
    )
  end
end
