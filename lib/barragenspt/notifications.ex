defmodule Barragenspt.Notifications do
  @moduledoc """
  User-configured storage alerts and trigger history.
  """
  import Ecto.Query

  alias Barragenspt.Repo
  alias Barragenspt.Notifications.{UserAlert, AlertEvent, AlertMetrics}

  def list_alerts_with_stats(user_id) do
    alerts =
      Repo.all(
        from(a in UserAlert,
          where: a.user_id == ^user_id,
          order_by: [desc: a.inserted_at]
        )
      )

    Enum.map(alerts, fn alert ->
      triggered_count =
        Repo.aggregate(from(e in AlertEvent, where: e.alert_id == ^alert.id), :count)

      last_triggered_at =
        Repo.one(
          from(e in AlertEvent,
            where: e.alert_id == ^alert.id,
            select: max(e.triggered_at)
          )
        )

      %{alert: alert, triggered_count: triggered_count, last_triggered_at: last_triggered_at}
    end)
  end

  def get_alert!(id, user_id) do
    Repo.one!(from(a in UserAlert, where: a.id == ^id and a.user_id == ^user_id))
  end

  @doc """
  Fetches a single alert for the user, or `{:error, :not_found}`.
  `id` may be a string (from URL params) or integer.
  """
  def get_alert(id, user_id) do
    case parse_alert_id(id) do
      {:ok, int_id} ->
        case Repo.get_by(UserAlert, id: int_id, user_id: user_id) do
          nil -> {:error, :not_found}
          %UserAlert{} = alert -> {:ok, alert}
        end

      :error ->
        {:error, :not_found}
    end
  end

  defp parse_alert_id(id) when is_integer(id), do: {:ok, id}

  defp parse_alert_id(id) when is_binary(id) do
    case Integer.parse(String.trim(id)) do
      {int, _} -> {:ok, int}
      :error -> :error
    end
  end

  defp parse_alert_id(_), do: :error

  @doc """
  Updates alert fields (subject, condition, notifications). Scoped by user.
  """
  def update_alert(id, user_id, attrs) do
    with {:ok, alert} <- get_alert(id, user_id) do
      attrs = Map.put(attrs, :user_id, user_id)

      alert
      |> UserAlert.changeset(attrs)
      |> Repo.update()
    end
  end

  def create_alert(attrs) do
    %UserAlert{}
    |> UserAlert.changeset(attrs)
    |> Repo.insert()
  end

  def delete_alert(id, user_id) do
    case Repo.one(from(a in UserAlert, where: a.id == ^id and a.user_id == ^user_id)) do
      nil -> {:error, :not_found}
      alert -> Repo.delete(alert)
    end
  end

  def toggle_active(id, user_id) do
    case Repo.one(from(a in UserAlert, where: a.id == ^id and a.user_id == ^user_id)) do
      nil ->
        {:error, :not_found}

      alert ->
        alert
        |> UserAlert.update_changeset(%{active: !alert.active})
        |> Repo.update()
    end
  end

  def update_after_notification(alert, attrs) do
    alert
    |> UserAlert.update_changeset(attrs)
    |> Repo.update()
  end

  def create_event!(attrs) do
    %AlertEvent{}
    |> AlertEvent.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  When condition is no longer met, clear episodic notification state so the next breach can notify.
  """
  def clear_breach_state_if_needed(alert, condition_met?) do
    if !condition_met? && alert.repeat_mode == "once_per_event" && alert.breach_notification_sent do
      update_after_notification(alert, %{breach_notification_sent: false})
    else
      {:ok, alert}
    end
  end

  def compute_status(alert) do
    value = AlertMetrics.current_value(alert)
    met? = AlertMetrics.condition_met?(value, alert.operator, alert.threshold)
    {met?, value}
  end

  defdelegate current_value(alert), to: AlertMetrics
  defdelegate condition_met?(v, op, t), to: AlertMetrics
end
