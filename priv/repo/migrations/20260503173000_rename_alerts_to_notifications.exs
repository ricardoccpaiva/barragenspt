defmodule Barragenspt.Repo.Migrations.RenameAlertsToNotifications do
  use Ecto.Migration

  def up do
    rename table(:user_alerts), to: table(:user_notifications)
    rename table(:alert_events), to: table(:notification_events)
    rename table(:notification_events), :alert_id, to: :notification_id

    execute("ALTER INDEX IF EXISTS alert_events_alert_id_index RENAME TO notification_events_notification_id_index")
    execute("ALTER INDEX IF EXISTS user_alerts_user_id_index RENAME TO user_notifications_user_id_index")
    execute("ALTER INDEX IF EXISTS user_alerts_active_index RENAME TO user_notifications_active_index")
  end

  def down do
    execute("ALTER INDEX IF EXISTS user_notifications_user_id_index RENAME TO user_alerts_user_id_index")
    execute("ALTER INDEX IF EXISTS user_notifications_active_index RENAME TO user_alerts_active_index")
    execute("ALTER INDEX IF EXISTS notification_events_notification_id_index RENAME TO alert_events_alert_id_index")

    rename table(:notification_events), :notification_id, to: :alert_id
    rename table(:notification_events), to: table(:alert_events)
    rename table(:user_notifications), to: table(:user_alerts)
  end
end
