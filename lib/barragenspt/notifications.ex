defmodule Barragenspt.Notifications do
  @moduledoc """
  User-configured notifications and trigger history.
  """
  import Ecto.Query

  alias Barragenspt.Repo
  alias Barragenspt.Notifications.{UserNotification, NotificationEvent, NotificationMetrics}

  def list_notifications_with_stats(user_id) do
    notifications =
      Repo.all(
        from(n in UserNotification,
          where: n.user_id == ^user_id,
          order_by: [desc: n.inserted_at]
        )
      )

    Enum.map(notifications, fn notification ->
      triggered_count =
        Repo.aggregate(
          from(e in NotificationEvent, where: e.notification_id == ^notification.id),
          :count
        )

      last_triggered_at =
        Repo.one(
          from(e in NotificationEvent,
            where: e.notification_id == ^notification.id,
            select: max(e.triggered_at)
          )
        )

      %{
        notification: notification,
        triggered_count: triggered_count,
        last_triggered_at: last_triggered_at
      }
    end)
  end

  def get_notification!(id, user_id) do
    Repo.one!(from(n in UserNotification, where: n.id == ^id and n.user_id == ^user_id))
  end

  @doc """
  Loads a notification and its trigger events (newest first). Returns `{:error, :not_found}` if the notification
  does not belong to the user.
  """
  def fetch_notification_with_events(id, user_id) do
    with {:ok, notification} <- get_notification(id, user_id) do
      events =
        Repo.all(
          from(e in NotificationEvent,
            where: e.notification_id == ^notification.id,
            order_by: [desc: e.triggered_at]
          )
        )

      {:ok, notification, events}
    end
  end

  @doc """
  Fetches a single notification for the user, or `{:error, :not_found}`.
  `id` may be a string (from URL params) or integer.
  """
  def get_notification(id, user_id) do
    case parse_notification_id(id) do
      {:ok, int_id} ->
        case Repo.get_by(UserNotification, id: int_id, user_id: user_id) do
          nil -> {:error, :not_found}
          %UserNotification{} = notification -> {:ok, notification}
        end

      :error ->
        {:error, :not_found}
    end
  end

  defp parse_notification_id(id) when is_integer(id), do: {:ok, id}

  defp parse_notification_id(id) when is_binary(id) do
    case Integer.parse(String.trim(id)) do
      {int, _} -> {:ok, int}
      :error -> :error
    end
  end

  defp parse_notification_id(_), do: :error

  @doc """
  Updates notification fields (subject, condition, notifications). Scoped by user.
  """
  def update_notification(id, user_id, attrs) do
    with {:ok, notification} <- get_notification(id, user_id) do
      attrs = Map.put(attrs, :user_id, user_id)

      notification
      |> UserNotification.changeset(attrs)
      |> Repo.update()
    end
  end

  def create_notification(attrs) do
    %UserNotification{}
    |> UserNotification.changeset(attrs)
    |> Repo.insert()
  end

  def delete_notification(id, user_id) do
    case Repo.one(from(n in UserNotification, where: n.id == ^id and n.user_id == ^user_id)) do
      nil -> {:error, :not_found}
      notification -> Repo.delete(notification)
    end
  end

  def toggle_notification_active(id, user_id) do
    case Repo.one(from(n in UserNotification, where: n.id == ^id and n.user_id == ^user_id)) do
      nil ->
        {:error, :not_found}

      notification ->
        notification
        |> UserNotification.update_changeset(%{active: !notification.active})
        |> Repo.update()
    end
  end

  def update_after_notification(notification, attrs) do
    notification
    |> UserNotification.update_changeset(attrs)
    |> Repo.update()
  end

  def create_notification_event!(attrs) do
    %NotificationEvent{}
    |> NotificationEvent.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  When condition is no longer met, clear episodic notification state so the next breach can notify.
  """
  def clear_breach_state_if_needed(notification, condition_met?) do
    if !condition_met? && notification.repeat_mode == "once_per_event" &&
         notification.breach_notification_sent do
      update_after_notification(notification, %{breach_notification_sent: false})
    else
      {:ok, notification}
    end
  end

  def compute_status(notification) do
    value = NotificationMetrics.current_value(notification)
    met? = NotificationMetrics.condition_met_for_alert(notification)
    {met?, value}
  end

  defdelegate current_value(notification), to: NotificationMetrics
  defdelegate condition_met?(v, op, t), to: NotificationMetrics

end
