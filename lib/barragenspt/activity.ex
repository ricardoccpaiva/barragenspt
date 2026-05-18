defmodule Barragenspt.Activity do
  @moduledoc """
  User activity events and dashboard summaries.
  """

  import Ecto.Query

  alias Barragenspt.Activity.UserActivityEvent
  alias Barragenspt.ApiUsage
  alias Barragenspt.Notifications.{NotificationEvent, UserNotification}
  alias Barragenspt.Repo

  @data_export "data_points_csv_export"
  @data_view "data_points_view"
  @report_generated "storage_report_generated"
  @report_pdf_exported "storage_report_pdf_exported"

  def data_export_event, do: @data_export
  def data_view_event, do: @data_view
  def report_generated_event, do: @report_generated
  def report_pdf_exported_event, do: @report_pdf_exported

  def record_event(user_id, event_type, metadata \\ %{})

  def record_event(nil, _event_type, _metadata), do: {:error, :missing_user}

  def record_event(user_id, event_type, metadata) when is_integer(user_id) do
    %UserActivityEvent{}
    |> UserActivityEvent.changeset(%{
      user_id: user_id,
      event_type: event_type,
      metadata: metadata || %{},
      occurred_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  def summary_for_user(user_id) when is_integer(user_id) do
    activity_counts = activity_counts_by_type(user_id)
    notification_summary = notification_summary(user_id)
    notification_triggers = notification_trigger_summary(user_id)

    %{
      api_calls: ApiUsage.total_request_count(user_id),
      data_views: Map.get(activity_counts, @data_view, 0),
      data_exports: Map.get(activity_counts, @data_export, 0),
      reports_generated: Map.get(activity_counts, @report_generated, 0),
      report_pdf_exports: Map.get(activity_counts, @report_pdf_exported, 0),
      notifications_triggered: notification_summary.total,
      notification_channels: notification_summary.channels,
      notification_triggers: notification_triggers
    }
  end

  defp activity_counts_by_type(user_id) do
    from(e in UserActivityEvent,
      where: e.user_id == ^user_id,
      group_by: e.event_type,
      select: {e.event_type, count(e.id)}
    )
    |> Repo.all()
    |> Map.new(fn {type, count} -> {type, count} end)
  end

  defp notification_summary(user_id) do
    query =
      from(e in NotificationEvent,
        join: n in UserNotification,
        on: n.id == e.notification_id,
        where: n.user_id == ^user_id and e.notified == true
      )

    total = Repo.aggregate(query, :count)

    channels =
      query
      |> select([e, _n], e.notification_channels)
      |> Repo.all()
      |> List.flatten()
      |> Enum.reject(&is_nil/1)
      |> Enum.frequencies()

    %{total: total, channels: channels}
  end

  defp notification_trigger_summary(user_id) do
    rows =
      from(n in UserNotification,
        where: n.user_id == ^user_id,
        group_by: n.active,
        select: {n.active, count(n.id)}
      )
      |> Repo.all()
      |> Map.new(fn {active?, count} -> {active?, count} end)

    active = Map.get(rows, true, 0)
    inactive = Map.get(rows, false, 0)

    %{total: active + inactive, active: active, inactive: inactive}
  end
end
