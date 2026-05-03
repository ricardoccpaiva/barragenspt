defmodule Barragenspt.Workers.EvaluateNotifications do
  @moduledoc """
  Evaluates active user notifications after materialized views are fresh.
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
  alias Barragenspt.Notifications.{UserNotification, NotificationMetrics}

  @doc """
  Enqueue a full pass over active notifications (same as after a materialized-view refresh).
  `id_prefix` is stored in job args for logs (e.g. `"navbar"`, `"manual"`).
  """
  def schedule_manual(id_prefix \\ "manual") do
    %{"id" => "#{id_prefix}-#{:erlang.unique_integer([:positive])}"}
    |> new()
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{attempt: 1, args: %{"id" => job_id}}) do
    Logger.info("EvaluateNotifications starting oban_job_id=#{job_id}")

    notifications = Repo.all(from(n in UserNotification, where: n.active == true))
    Logger.info("EvaluateNotifications loaded #{length(notifications)} active notification(s)")

    Enum.each(notifications, &evaluate_notification(&1, job_id))

    Logger.info("EvaluateNotifications finished oban_job_id=#{job_id}")

    :ok
  end

  defp evaluate_notification(notification, oban_job_id) do
    user = Repo.get(User, notification.user_id)
    value = NotificationMetrics.current_value(notification)
    met? = NotificationMetrics.condition_met_for_alert(notification)

    Logger.debug(
      "----> EvaluateNotifications notification_id=#{notification.id} oban_job_id=#{oban_job_id} " <>
        "subject=#{inspect(notification.subject_name)} type=#{notification.subject_type} " <>
        "metric=#{notification.metric} value=#{inspect(value)} " <>
        "check=(#{notification.operator} #{inspect(notification.threshold)}) met=#{met?}"
    )

    cond do
      user == nil ->
        Logger.warning(
          "EvaluateNotifications notification_id=#{notification.id}: no user for user_id=#{notification.user_id}, skipping"
        )

      met? ->
        maybe_fire(notification, user, value, oban_job_id)

      true ->
        Notifications.clear_breach_state_if_needed(notification, false)

        Logger.debug(
          "EvaluateNotifications notification_id=#{notification.id}: condition not met, cleared breach state if needed"
        )
    end
  end

  defp maybe_fire(notification, user, value, oban_job_id) do
    should? =
      case notification.repeat_mode do
        "once_per_event" ->
          !notification.breach_notification_sent

        "cooldown" ->
          case notification.last_notified_at do
            nil -> true
            t -> DateTime.diff(DateTime.utc_now(), t, :second) >= notification.cooldown_hours * 3600
          end

        "always" ->
          true

        other ->
          Logger.warning(
            "EvaluateNotifications notification_id=#{notification.id}: unknown repeat_mode=#{inspect(other)}, will not notify"
          )

          false
      end

    if should? do
      fire(notification, user, value, oban_job_id)
    else
      Logger.debug(
        "EvaluateNotifications notification_id=#{notification.id} oban_job_id=#{oban_job_id}: " <>
          "condition met but delivery suppressed " <>
          "(repeat_mode=#{notification.repeat_mode}, breach_notification_sent=#{notification.breach_notification_sent}, " <>
          "last_notified_at=#{inspect(notification.last_notified_at)}, cooldown_hours=#{notification.cooldown_hours})"
      )
    end
  end

  defp fire(notification, user, value, oban_job_id) do
    now = DateTime.utc_now()

    email_result = maybe_deliver_email(user, notification, value)
    telegram_result = maybe_deliver_telegram(user, notification, value)
    channels = delivered_channels(email_result, telegram_result)
    notified? = delivered?(email_result) or delivered?(telegram_result)

    log_delivery_result("email", email_result, notification, user, value, oban_job_id)
    log_delivery_result("telegram", telegram_result, notification, user, value, oban_job_id)

    if notified? do
      Notifications.create_notification_event!(%{
        notification_id: notification.id,
        triggered_at: now,
        value_at_trigger: value,
        notified: true,
        notification_channels: channels
      })

      attrs =
        if notification.repeat_mode == "once_per_event" do
          %{breach_notification_sent: true, last_notified_at: now}
        else
          %{last_notified_at: now}
        end

      Notifications.update_after_notification(notification, attrs)
    else
      Logger.warning(
        "EvaluateNotifications notification_id=#{notification.id} oban_job_id=#{oban_job_id}: all notification channels failed"
      )
    end
  end

  defp maybe_deliver_email(user, notification, value) do
    if user_email_notifications_enabled?(user) do
      UserNotifier.deliver_alert_triggered(user, notification, value)
    else
      {:skipped, :email_disabled}
    end
  end

  defp maybe_deliver_telegram(user, notification, value) do
    if user.telegram_enabled do
      UserNotifier.deliver_alert_triggered_telegram(user, notification, value)
    else
      {:skipped, :telegram_disabled}
    end
  end

  defp user_email_notifications_enabled?(user),
    do: Map.get(user, :email_notifications_enabled, true) != false

  defp delivered_channels(email_result, telegram_result) do
    []
    |> maybe_add_channel("email", email_result)
    |> maybe_add_channel("telegram", telegram_result)
    |> Enum.reverse()
  end

  defp maybe_add_channel(channels, channel, result) do
    if delivered?(result), do: [channel | channels], else: channels
  end

  defp delivered?({:ok, _}), do: true
  defp delivered?(_), do: false

  defp log_delivery_result(channel, {:ok, _}, notification, user, value, oban_job_id) do
    Logger.info(
      "EvaluateNotifications notification_id=#{notification.id} oban_job_id=#{oban_job_id} " <>
        "user_id=#{user.id}: #{channel} sent for triggered notification value=#{inspect(value)}"
    )
  end

  defp log_delivery_result(channel, {:skipped, reason}, notification, user, _value, oban_job_id) do
    Logger.debug(
      "EvaluateNotifications notification_id=#{notification.id} oban_job_id=#{oban_job_id} " <>
        "user_id=#{user.id}: #{channel} skipped #{inspect(reason)}"
    )
  end

  defp log_delivery_result(channel, {:error, reason}, notification, user, _value, oban_job_id) do
    Logger.warning(
      "EvaluateNotifications notification_id=#{notification.id} oban_job_id=#{oban_job_id} " <>
        "user_id=#{user.id}: #{channel} failed #{inspect(reason)}"
    )
  end
end
