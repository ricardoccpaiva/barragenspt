defmodule Barragenspt.Models.WorkerRun do
  use Ecto.Schema
  import Ecto.Changeset

  schema "worker_runs" do
    field :worker, :string
    field :cron_expr, :string
    field :run_key, :string
    field :oban_job_id, :integer
    field :status, :string, default: "running"
    field :started_at, :utc_datetime_usec
    field :finished_at, :utc_datetime_usec
    field :duration_ms, :integer
    field :rows_created, :integer, default: 0
    field :rows_updated, :integer, default: 0
    field :error_message, :string
    field :meta, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(worker_run, attrs) do
    worker_run
    |> cast(attrs, [
      :worker,
      :cron_expr,
      :run_key,
      :oban_job_id,
      :status,
      :started_at,
      :finished_at,
      :duration_ms,
      :rows_created,
      :rows_updated,
      :error_message,
      :meta
    ])
    |> validate_required([:worker, :run_key, :status, :started_at])
    |> validate_inclusion(:status, ["running", "ok", "error"])
    |> unique_constraint(:run_key)
  end
end
