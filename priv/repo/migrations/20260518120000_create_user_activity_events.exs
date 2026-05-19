defmodule Barragenspt.Repo.Migrations.CreateUserActivityEvents do
  use Ecto.Migration

  def change do
    create table(:user_activity_events) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :event_type, :string, null: false
      add :metadata, :map, null: false, default: %{}
      add :occurred_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:user_activity_events, [:user_id, :event_type])
    create index(:user_activity_events, [:user_id, :occurred_at])
  end
end
