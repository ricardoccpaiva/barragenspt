defmodule Barragenspt.Admin do
  @moduledoc """
  Admin analytics focused on API usage.
  """
  import Ecto.Query, warn: false

  alias Barragenspt.Accounts.{User, UserApiToken}
  alias Barragenspt.ApiUsage
  alias Barragenspt.ApiUsage.ApiTokenUsageBucket
  alias Barragenspt.Notifications.{NotificationEvent, UserNotification}
  alias Barragenspt.Repo

  @spike_threshold 200
  @stack_colors [
    "rgba(14, 165, 233, 0.86)",
    "rgba(16, 185, 129, 0.86)",
    "rgba(245, 158, 11, 0.86)",
    "rgba(244, 63, 94, 0.86)",
    "rgba(139, 92, 246, 0.86)",
    "rgba(20, 184, 166, 0.86)",
    "rgba(234, 88, 12, 0.86)",
    "rgba(99, 102, 241, 0.86)"
  ]

  def usage_series(window) do
    since = since_for_window(window)

    db_map =
      from(b in ApiTokenUsageBucket,
        where: b.bucket_start >= ^since,
        group_by: b.bucket_start,
        select: {b.bucket_start, sum(b.request_count)}
      )
      |> Repo.all()
      |> Map.new(fn {bucket, count} -> {bucket, decimal_to_int(count)} end)

    ets_map =
      ets_rows_since(since)
      |> Enum.reduce(%{}, fn %{bucket_start: bucket, request_count: count}, acc ->
        Map.update(acc, bucket, count, &(&1 + count))
      end)

    db_map
    |> Map.merge(ets_map, fn _k, d, e -> d + e end)
    |> Enum.sort_by(fn {bucket, _} -> DateTime.to_unix(bucket, :second) end)
    |> Enum.map(fn {bucket, count} -> %{bucket_start: bucket, request_count: count} end)
  end

  def api_totals(window) do
    since = since_for_window(window)

    # approximate distinct total for dashboard KPI (DB + ETS union)
    users_with_usage =
      from(b in ApiTokenUsageBucket,
        where: b.bucket_start >= ^since,
        select: b.user_id,
        distinct: true
      )
      |> Repo.all()
      |> Kernel.++(ets_rows_since(since) |> Enum.map(& &1.user_id))
      |> Enum.uniq()
      |> length()

    %{
      requests: requests_in_window(since) + ets_total_requests(since),
      active_api_tokens: active_api_tokens_count(),
      users_with_usage: users_with_usage,
      spike_buckets: api_spike_count(window)
    }
  end

  def api_usage_by_user(window, limit \\ 8) when is_integer(limit) and limit > 0 do
    since = since_for_window(window)

    db_counts =
      from(b in ApiTokenUsageBucket,
        where: b.bucket_start >= ^since,
        group_by: b.user_id,
        select: {b.user_id, sum(b.request_count)}
      )
      |> Repo.all()
      |> Map.new(fn {uid, n} -> {uid, decimal_to_int(n)} end)

    counts =
      ets_rows_since(since)
      |> Enum.reduce(db_counts, fn %{user_id: uid, request_count: n}, acc ->
        Map.update(acc, uid, n, &(&1 + n))
      end)

    emails =
      from(u in User, select: {u.id, u.email})
      |> Repo.all()
      |> Map.new()

    counts
    |> Enum.map(fn {uid, n} -> %{user_id: uid, email: Map.get(emails, uid, "unknown"), request_count: n} end)
    |> Enum.sort_by(& &1.request_count, :desc)
    |> Enum.take(limit)
  end

  def api_usage_by_token(window, limit \\ 8) when is_integer(limit) and limit > 0 do
    since = since_for_window(window)

    db_counts =
      from(b in ApiTokenUsageBucket,
        where: b.bucket_start >= ^since,
        group_by: b.user_api_token_id,
        select: {b.user_api_token_id, sum(b.request_count)}
      )
      |> Repo.all()
      |> Map.new(fn {tid, n} -> {tid, decimal_to_int(n)} end)

    counts =
      ets_rows_since(since)
      |> Enum.reduce(db_counts, fn %{token_id: tid, request_count: n}, acc ->
        Map.update(acc, tid, n, &(&1 + n))
      end)

    prefixes =
      from(t in UserApiToken, select: {t.id, t.token_prefix})
      |> Repo.all()
      |> Map.new()

    counts
    |> Enum.map(fn {tid, n} ->
      %{token_id: tid, token_prefix: Map.get(prefixes, tid, "token"), request_count: n}
    end)
    |> Enum.sort_by(& &1.request_count, :desc)
    |> Enum.take(limit)
  end

  def api_usage_stacked_chart(window, token_limit \\ 8)
      when is_integer(token_limit) and token_limit > 0 do
    since = since_for_window(window)

    db_map =
      from(b in ApiTokenUsageBucket,
        where: b.bucket_start >= ^since,
        group_by: [b.user_api_token_id, b.bucket_start],
        select: {{b.user_api_token_id, b.bucket_start}, sum(b.request_count)}
      )
      |> Repo.all()
      |> Map.new(fn {k, n} -> {k, decimal_to_int(n)} end)

    merged =
      ets_rows_since(since)
      |> Enum.reduce(db_map, fn %{token_id: tid, bucket_start: b, request_count: n}, acc ->
        Map.update(acc, {tid, b}, n, &(&1 + n))
      end)

    token_totals =
      merged
      |> Enum.reduce(%{}, fn {{tid, _bucket}, count}, acc ->
        Map.update(acc, tid, count, &(&1 + count))
      end)
      |> Enum.sort_by(fn {_tid, total} -> total end, :desc)
      |> Enum.take(token_limit)

    token_ids = Enum.map(token_totals, &elem(&1, 0))

    bucket_starts =
      merged
      |> Map.keys()
      |> Enum.map(&elem(&1, 1))
      |> Enum.uniq()
      |> Enum.sort_by(&DateTime.to_unix(&1, :second))

    prefixes =
      from(t in UserApiToken, select: {t.id, t.token_prefix})
      |> Repo.all()
      |> Map.new()

    labels =
      Enum.map(bucket_starts, fn bucket ->
        bucket
        |> DateTime.shift_zone!("Europe/Lisbon")
        |> Calendar.strftime("%d/%m %H:%M")
      end)

    datasets =
      token_ids
      |> Enum.with_index()
      |> Enum.map(fn {tid, i} ->
        %{
          label: token_chart_label(tid, prefixes),
          data: Enum.map(bucket_starts, fn bucket -> Map.get(merged, {tid, bucket}, 0) end),
          backgroundColor: Enum.at(@stack_colors, rem(i, length(@stack_colors)))
        }
      end)

    %{labels: labels, datasets: datasets}
  end

  def notifications_totals(window) do
    since = since_for_window(window)

    triggered_events =
      from(e in NotificationEvent, where: e.triggered_at >= ^since)
      |> Repo.aggregate(:count)

    notified_events =
      from(e in NotificationEvent, where: e.triggered_at >= ^since and e.notified == true)
      |> Repo.aggregate(:count)

    users_with_notification_events =
      from(e in NotificationEvent,
        join: a in UserNotification,
        on: a.id == e.notification_id,
        where: e.triggered_at >= ^since,
        select: a.user_id,
        distinct: true
      )
      |> Repo.aggregate(:count)

    active_notifications =
      from(a in UserNotification, where: a.active == true)
      |> Repo.aggregate(:count)

    %{
      active_notifications: active_notifications,
      triggered_events: triggered_events,
      notified_events: notified_events,
      users_with_notification_events: users_with_notification_events
    }
  end

  def notifications_stacked_chart(window, alert_limit \\ 8)
      when is_integer(alert_limit) and alert_limit > 0 do
    since = since_for_window(window)
    bucket = if window == "24h", do: :hour, else: :day

    rows =
      from(e in NotificationEvent,
        where: e.triggered_at >= ^since,
        select: {e.notification_id, e.triggered_at}
      )
      |> Repo.all()

    totals =
      rows
      |> Enum.reduce(%{}, fn {notification_id, _}, acc -> Map.update(acc, notification_id, 1, &(&1 + 1)) end)
      |> Enum.sort_by(fn {_id, n} -> n end, :desc)
      |> Enum.take(alert_limit)

    notification_ids = Enum.map(totals, &elem(&1, 0))

    grouped =
      rows
      |> Enum.reduce(%{}, fn {notification_id, triggered_at}, acc ->
        if notification_id in notification_ids do
          b = truncate_bucket(triggered_at, bucket)
          Map.update(acc, {notification_id, b}, 1, &(&1 + 1))
        else
          acc
        end
      end)

    buckets =
      grouped
      |> Map.keys()
      |> Enum.map(&elem(&1, 1))
      |> Enum.uniq()
      |> Enum.sort_by(&DateTime.to_unix(&1, :second))

    alert_labels =
      from(a in UserNotification,
        where: a.id in ^notification_ids,
        select: {a.id, a.subject_name}
      )
      |> Repo.all()
      |> Map.new()

    labels =
      Enum.map(buckets, fn bucket ->
        bucket
        |> DateTime.shift_zone!("Europe/Lisbon")
        |> Calendar.strftime("%d/%m %H:%M")
      end)

    datasets =
      notification_ids
      |> Enum.with_index()
      |> Enum.map(fn {notification_id, i} ->
        %{
          label: notification_chart_label(notification_id, alert_labels),
          data: Enum.map(buckets, fn b -> Map.get(grouped, {notification_id, b}, 0) end),
          backgroundColor: Enum.at(@stack_colors, rem(i, length(@stack_colors)))
        }
      end)

    %{labels: labels, datasets: datasets}
  end

  def notifications_by_user(window, limit \\ 8) when is_integer(limit) and limit > 0 do
    since = since_for_window(window)

    from(e in NotificationEvent,
      join: a in UserNotification,
      on: a.id == e.notification_id,
      join: u in User,
      on: u.id == a.user_id,
      where: e.triggered_at >= ^since,
      group_by: [u.id, u.email],
      order_by: [desc: count(e.notification_id)],
      limit: ^limit,
      select: %{user_id: u.id, email: u.email, event_count: count(e.notification_id)}
    )
    |> Repo.all()
  end

  def notifications_by_notification(window, limit \\ 8) when is_integer(limit) and limit > 0 do
    since = since_for_window(window)

    from(e in NotificationEvent,
      join: a in UserNotification,
      on: a.id == e.notification_id,
      where: e.triggered_at >= ^since,
      group_by: [e.notification_id, a.subject_name],
      order_by: [desc: count(e.notification_id)],
      limit: ^limit,
      select: %{notification_id: e.notification_id, subject_name: a.subject_name, event_count: count(e.notification_id)}
    )
    |> Repo.all()
  end

  def api_spike_count(window) do
    since = since_for_window(window)

    db_map =
      from(b in ApiTokenUsageBucket,
        where: b.bucket_start >= ^since,
        group_by: [b.user_id, b.user_api_token_id, b.bucket_start],
        select: {{b.user_id, b.user_api_token_id, b.bucket_start}, sum(b.request_count)}
      )
      |> Repo.all()
      |> Map.new(fn {k, n} -> {k, decimal_to_int(n)} end)

    merged =
      ets_rows_since(since)
      |> Enum.reduce(db_map, fn %{user_id: uid, token_id: tid, bucket_start: b, request_count: n}, acc ->
        Map.update(acc, {uid, tid, b}, n, &(&1 + n))
      end)

    merged
    |> Enum.count(fn {_k, n} -> n >= @spike_threshold end)
  end

  def since_for_window(window) do
    now = DateTime.utc_now()

    case window do
      "7d" -> DateTime.add(now, -7 * 24 * 3600, :second)
      "30d" -> DateTime.add(now, -30 * 24 * 3600, :second)
      _ -> DateTime.add(now, -24 * 3600, :second)
    end
  end

  defp active_api_tokens_count do
    from(t in UserApiToken, where: is_nil(t.revoked_at) and is_nil(t.deleted_at))
    |> Repo.aggregate(:count)
  end

  defp requests_in_window(since) do
    from(b in ApiTokenUsageBucket, where: b.bucket_start >= ^since, select: sum(b.request_count))
    |> Repo.one()
    |> decimal_to_int()
  end

  defp ets_rows_since(since) do
    table = ApiUsage.ets_table_name()

    if :ets.whereis(table) == :undefined do
      []
    else
      :ets.tab2list(table)
      |> Enum.reduce([], fn
        {{uid, tid, bucket_start}, count}, acc when is_integer(uid) and is_integer(tid) ->
          if DateTime.compare(bucket_start, since) != :lt do
            [%{user_id: uid, token_id: tid, bucket_start: bucket_start, request_count: count} | acc]
          else
            acc
          end

        _, acc ->
          acc
      end)
    end
  end

  defp ets_total_requests(since) do
    ets_rows_since(since)
    |> Enum.reduce(0, fn %{request_count: n}, acc -> acc + n end)
  end

  defp decimal_to_int(nil), do: 0
  defp decimal_to_int(n) when is_integer(n), do: n
  defp decimal_to_int(%Decimal{} = d), do: d |> Decimal.round(0) |> Decimal.to_integer()

  defp token_chart_label(tid, prefixes) do
    prefix = Map.get(prefixes, tid, "token")
    "##{tid} (#{prefix}…)"
  end

  defp notification_chart_label(notification_id, labels) do
    subject = Map.get(labels, notification_id, "notificação")
    "##{notification_id} (#{subject})"
  end

  defp truncate_bucket(%DateTime{} = dt, :hour) do
    %{dt | minute: 0, second: 0, microsecond: {0, 0}}
    |> DateTime.truncate(:second)
  end

  defp truncate_bucket(%DateTime{} = dt, :day) do
    %{dt | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
    |> DateTime.truncate(:second)
  end
end
