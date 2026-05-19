defmodule Barragenspt.Repo.Migrations.AddNotificationChannelsToAlertEvents do
  use Ecto.Migration

  def change do
    alter table(:alert_events) do
      add :notification_channels, {:array, :string}, null: false, default: []
    end
  end
end
