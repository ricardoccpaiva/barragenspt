defmodule Barragenspt.Repo.Migrations.CreateWorkerRuns do
  use Ecto.Migration

  def change do
    create table(:worker_runs) do
      add :worker, :string, null: false
      add :cron_expr, :string
      add :run_key, :string, null: false
      add :oban_job_id, :bigint
      add :status, :string, null: false, default: "running"
      add :started_at, :utc_datetime_usec, null: false
      add :finished_at, :utc_datetime_usec
      add :duration_ms, :integer
      add :rows_created, :integer, null: false, default: 0
      add :rows_updated, :integer, null: false, default: 0
      add :error_message, :text
      add :meta, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:worker_runs, [:run_key])
    create index(:worker_runs, [:worker, :started_at])
    create index(:worker_runs, [:status])
  end
end
