defmodule Barragenspt.Repo.Migrations.CreateUserAlerts do
  use Ecto.Migration

  def change do
    create table(:user_alerts) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :subject_type, :string, null: false
      add :subject_id, :string
      add :subject_name, :string, null: false
      add :metric, :string, null: false
      add :operator, :string, null: false
      add :threshold, :float, null: false
      add :repeat_mode, :string, null: false, default: "cooldown"
      add :cooldown_hours, :integer, null: false, default: 24
      add :active, :boolean, null: false, default: true
      add :breach_notification_sent, :boolean, null: false, default: false
      add :last_notified_at, :utc_datetime_usec

      timestamps()
    end

    create index(:user_alerts, [:user_id])
    create index(:user_alerts, [:active])

    create table(:alert_events) do
      add :alert_id, references(:user_alerts, on_delete: :delete_all), null: false
      add :triggered_at, :utc_datetime_usec, null: false
      add :value_at_trigger, :float, null: false
      add :notified, :boolean, null: false, default: false
    end

    create index(:alert_events, [:alert_id])
  end
end
