defmodule Barragenspt.WorkerStatus do
  import Ecto.Query

  alias Barragenspt.Models.WorkerRun
  alias Barragenspt.Repo
  alias Oban.Cron.Expression
  alias Oban.Job

  @display_tz "Europe/Lisbon"
  @tracked_workers [
    Barragenspt.Workers.DataPointsUpdate,
    Barragenspt.Workers.RealtimeDataPointsUpdate,
    Barragenspt.Workers.InfoaguaAlertsRefresh
  ]

  @error_states ["discarded", "cancelled"]

  def tracked_workers, do: @tracked_workers

  def cron_expression_for_worker(worker_module) when is_atom(worker_module) do
    worker = to_string(worker_module)

    cron_entries()
    |> Enum.find_value(fn {expr, current_worker, _opts} ->
      if current_worker == worker, do: expr, else: nil
    end)
  end

  def list_worker_summaries do
    now = DateTime.now!(@display_tz)

    Enum.map(@tracked_workers, fn worker_module ->
      worker = to_string(worker_module)
      cron_expr = cron_expression_for_worker(worker_module)
      latest_job = latest_oban_job(worker)
      latest_success = latest_successful_run_at(worker)
      latest_run = latest_worker_run(worker)
      next_run_at = cron_next_run(cron_expr, now)
      seconds_to_next = seconds_to_next_run(next_run_at, now)
      stale? = stale?(cron_expr, latest_success, now)
      executing? = executing?(worker)

      %{
        worker: worker,
        worker_module: worker_module,
        worker_name: worker_name(worker_module),
        cron_expr: cron_expr,
        next_run_at: next_run_at,
        seconds_to_next: seconds_to_next,
        last_run_at: last_run_at(latest_run, latest_job),
        status: compute_status(executing?, latest_job, latest_run, stale?),
        rows_created: (latest_run && latest_run.rows_created) || 0,
        rows_updated: (latest_run && latest_run.rows_updated) || 0,
        duration_ms: latest_run && latest_run.duration_ms,
        latest_oban_state: latest_job && latest_job.state
      }
    end)
  end

  def last_runs(worker_module, limit \\ 30) when is_atom(worker_module) and is_integer(limit) do
    worker = to_string(worker_module)

    from(r in WorkerRun,
      where: r.worker == ^worker,
      order_by: [desc: r.started_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  def summarize_runs(runs) when is_list(runs) do
    total = length(runs)
    ok_count = Enum.count(runs, &(&1.status == "ok"))
    error_count = Enum.count(runs, &(&1.status == "error"))
    running_count = Enum.count(runs, &(&1.status == "running"))
    total_created = Enum.reduce(runs, 0, &(&1.rows_created + &2))
    total_updated = Enum.reduce(runs, 0, &(&1.rows_updated + &2))

    avg_duration_ms =
      runs
      |> Enum.map(& &1.duration_ms)
      |> Enum.reject(&is_nil/1)
      |> case do
        [] -> nil
        durations -> round(Enum.sum(durations) / length(durations))
      end

    %{
      total: total,
      ok_count: ok_count,
      error_count: error_count,
      running_count: running_count,
      total_created: total_created,
      total_updated: total_updated,
      avg_duration_ms: avg_duration_ms
    }
  end

  def start_run(worker_module, run_key, oban_job_id, meta \\ %{}) when is_atom(worker_module) do
    now = DateTime.utc_now()
    cron_expr = cron_expression_for_worker(worker_module)

    attrs = %{
      worker: to_string(worker_module),
      cron_expr: cron_expr,
      run_key: run_key,
      oban_job_id: oban_job_id,
      status: "running",
      started_at: now,
      finished_at: nil,
      duration_ms: nil,
      rows_created: 0,
      rows_updated: 0,
      error_message: nil,
      meta: meta || %{}
    }

    %WorkerRun{}
    |> WorkerRun.changeset(attrs)
    |> Repo.insert(
      on_conflict: [
        set: [
          worker: attrs.worker,
          cron_expr: attrs.cron_expr,
          oban_job_id: attrs.oban_job_id,
          status: "running",
          started_at: now,
          finished_at: nil,
          duration_ms: nil,
          rows_created: 0,
          rows_updated: 0,
          error_message: nil,
          meta: attrs.meta,
          updated_at: now
        ]
      ],
      conflict_target: :run_key
    )
  end

  def add_rows(run_key, rows_created, rows_updated)
      when is_binary(run_key) and is_integer(rows_created) and is_integer(rows_updated) do
    now = DateTime.utc_now()

    Repo.query(
      """
      UPDATE worker_runs
      SET rows_created = rows_created + $1,
          rows_updated = rows_updated + $2,
          updated_at = $3
      WHERE run_key = $4
      """,
      [rows_created, rows_updated, now, run_key]
    )
  end

  def finish_run(run_key, status, error_message \\ nil)
      when is_binary(run_key) and status in ["ok", "error"] do
    case Repo.get_by(WorkerRun, run_key: run_key) do
      nil ->
        {:error, :not_found}

      run ->
        finished_at = DateTime.utc_now()
        duration_ms = DateTime.diff(finished_at, run.started_at, :millisecond)

        run
        |> WorkerRun.changeset(%{
          status: status,
          finished_at: finished_at,
          duration_ms: max(duration_ms, 0),
          error_message: error_message
        })
        |> Repo.update()
    end
  end

  def remaining_child_jobs(run_key, child_worker_module)
      when is_binary(run_key) and is_atom(child_worker_module) do
    worker = to_string(child_worker_module)

    from(j in Job,
      where:
        j.worker == ^worker and
          fragment("?->>'run_key' = ?", j.args, ^run_key) and
          j.state in ["available", "scheduled", "executing", "retryable"],
      select: count(j.id)
    )
    |> Repo.one()
  end

  def child_jobs_have_errors?(run_key, child_worker_module)
      when is_binary(run_key) and is_atom(child_worker_module) do
    worker = to_string(child_worker_module)

    from(j in Job,
      where:
        j.worker == ^worker and
          fragment("?->>'run_key' = ?", j.args, ^run_key) and
          j.state in @error_states,
      select: count(j.id)
    )
    |> Repo.one()
    |> Kernel.>(0)
  end

  defp worker_name(worker_module) do
    worker_module
    |> Module.split()
    |> List.last()
  end

  defp cron_entries do
    case Application.get_env(:barragenspt, Oban, []) |> Keyword.get(:plugins, []) do
      plugins when is_list(plugins) ->
        plugins
        |> Enum.find_value([], fn
          {Oban.Plugins.Cron, opts} -> normalize_cron_entries(Keyword.get(opts, :crontab, []))
          _ -> nil
        end)

      _ ->
        []
    end
  end

  defp normalize_cron_entries(crontab) do
    Enum.map(crontab, fn
      {expr, worker} ->
        {expr, to_string(worker), []}

      {expr, worker, opts} ->
        {expr, to_string(worker), opts}
    end)
  end

  defp latest_oban_job(worker) do
    from(j in Job,
      where: j.worker == ^worker,
      order_by: [desc: j.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  defp latest_successful_run_at(worker) do
    from(j in Job,
      where: j.worker == ^worker and j.state == "completed" and not is_nil(j.completed_at),
      order_by: [desc: j.completed_at],
      limit: 1,
      select: j.completed_at
    )
    |> Repo.one()
  end

  defp latest_worker_run(worker) do
    from(r in WorkerRun,
      where: r.worker == ^worker,
      order_by: [desc: r.started_at],
      limit: 1
    )
    |> Repo.one()
  end

  defp executing?(worker) do
    from(j in Job,
      where: j.worker == ^worker and j.state == "executing",
      select: count(j.id)
    )
    |> Repo.one()
    |> Kernel.>(0)
  end

  defp compute_status(true, _latest_job, _latest_run, _stale?), do: "running"

  defp compute_status(false, _latest_job, latest_run, _stale?)
       when is_map(latest_run) and latest_run.status == "running" do
    "running"
  end

  defp compute_status(false, latest_job, latest_run, _stale?)
       when is_map(latest_run) and latest_run.status == "error" do
    if is_error_job?(latest_job), do: "error", else: "error"
  end

  defp compute_status(false, latest_job, _latest_run, stale?) do
    cond do
      is_error_job?(latest_job) -> "error"
      stale? -> "stale"
      true -> "ok"
    end
  end

  defp is_error_job?(%Job{state: state}) when state in @error_states, do: true

  defp is_error_job?(%Job{state: "retryable", attempt: attempt, max_attempts: max_attempts})
       when is_integer(attempt) and is_integer(max_attempts) do
    attempt >= max_attempts
  end

  defp is_error_job?(_), do: false

  defp last_run_at(%WorkerRun{} = run, _latest_job), do: run.finished_at || run.started_at

  defp last_run_at(nil, %Job{} = job) do
    job.completed_at || job.attempted_at || job.inserted_at
  end

  defp last_run_at(nil, _), do: nil

  defp cron_next_run(nil, _now), do: nil

  defp cron_next_run(cron_expr, now) do
    cron_expr
    |> Expression.parse!()
    |> Expression.next_at(now)
  rescue
    _ -> nil
  end

  defp seconds_to_next_run(nil, _now), do: nil
  defp seconds_to_next_run(next_run_at, now), do: max(DateTime.diff(next_run_at, now, :second), 0)

  defp stale?(nil, _latest_success, _now), do: false

  defp stale?(cron_expr, latest_success, now) do
    parsed = Expression.parse!(cron_expr)
    expected_last = Expression.last_at(parsed, now)
    previous = Expression.last_at(parsed, DateTime.add(expected_last, -60, :second))
    interval_secs = max(DateTime.diff(expected_last, previous, :second), 60)
    grace_deadline = DateTime.add(expected_last, interval_secs, :second)

    DateTime.compare(now, grace_deadline) == :gt &&
      (is_nil(latest_success) || DateTime.compare(latest_success, expected_last) == :lt)
  rescue
    _ -> false
  end
end
