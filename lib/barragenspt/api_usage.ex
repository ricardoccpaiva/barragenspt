defmodule Barragenspt.ApiUsage do
  @moduledoc """
  In-memory API request counts per `(user_id, user_api_token_id, time bucket)` using ETS,
  flushed to `api_token_usage_buckets` by `Barragenspt.Workers.FlushApiUsage`.

  ETS is **node-local**; multiple nodes each hold partial counts unless traffic is sticky or
  you add a shared store.
  """

  import Ecto.Query

  alias Barragenspt.ApiUsage.ApiTokenUsageBucket
  alias Barragenspt.Repo

  @ets_table :barragenspt_api_usage_counters

  @usage_chart_max_bars 48
  @usage_chart_max_bars_filtered 400

  @token_chart_colors [
    "rgba(14, 165, 233, 0.88)",
    "rgba(16, 185, 129, 0.88)",
    "rgba(139, 92, 246, 0.88)",
    "rgba(245, 158, 11, 0.88)",
    "rgba(244, 63, 94, 0.88)"
  ]

  @doc false
  def ets_table_name, do: @ets_table

  @doc """
  Start of the current open bucket for `dt` in UTC (`:hour` or `:minute` from config).
  """
  def bucket_start(%DateTime{} = dt) do
    dt = DateTime.shift_zone!(dt, "Etc/UTC")
    secs = DateTime.to_unix(dt, :second)

    start_unix =
      case bucket_period() do
        :hour -> div(secs, 3600) * 3600
        :minute -> div(secs, 60) * 60
      end

    DateTime.from_unix!(start_unix, :second)
    |> DateTime.truncate(:second)
  end

  def bucket_start_now do
    bucket_start(DateTime.utc_now())
  end

  defp bucket_period do
    Application.get_env(:barragenspt, :api_usage_bucket, :hour)
  end

  @doc """
  Returns `%{user_api_token_id => total_request_count}` for the user: persisted bucket sums
  plus any counts still in ETS for the current open bucket(s).
  """
  def request_counts_by_token_id(user_id) when is_integer(user_id) do
    db =
      from(b in ApiTokenUsageBucket,
        where: b.user_id == ^user_id,
        group_by: b.user_api_token_id,
        select: {b.user_api_token_id, sum(b.request_count)}
      )
      |> Repo.all()
      |> Map.new(fn {tid, n} -> {tid, int_request_count(n)} end)

    user_id
    |> ets_inflight_counts_by_token()
    |> Enum.reduce(db, fn {tid, n}, acc ->
      Map.update(acc, tid, n, &(&1 + n))
    end)
  end

  defp int_request_count(nil), do: 0

  defp int_request_count(n) when is_integer(n), do: n

  defp int_request_count(%Decimal{} = d) do
    d |> Decimal.round(0) |> Decimal.to_integer()
  end

  @doc """
  Builds a Chart.js-friendly payload: stacked bar series per token, one bar per time bucket.
  Merges persisted buckets with in-flight ETS counts for the same `(token, bucket)`.

  ## Options

    * `:from_date`, `:to_date` — inclusive calendar dates in UTC. When both are set, only
      buckets in `[from_date 00:00 UTC, to_date end UTC]` are included (up to
      #{@usage_chart_max_bars_filtered} buckets, keeping the most recent if the range is larger).
    * When dates are omitted, uses the latest #{@usage_chart_max_bars} bucket intervals (current behaviour).
  """
  def usage_stacked_bar_chart(user_id, tokens, opts \\ [])

  def usage_stacked_bar_chart(user_id, tokens, opts)
      when is_integer(user_id) and is_list(tokens) and is_list(opts) do
    if tokens == [] do
      %{labels: [], datasets: []}
    else
      case Keyword.get(opts, :from_date) do
        %Date{} = from_date ->
          to_date = Keyword.fetch!(opts, :to_date)
          usage_stacked_bar_chart_for_range(user_id, tokens, from_date, to_date)

        _ ->
          usage_stacked_bar_chart_auto(user_id, tokens)
      end
    end
  end

  defp usage_stacked_bar_chart_auto(user_id, tokens) do
    max_bars = @usage_chart_max_bars

    db_buckets =
      from(b in ApiTokenUsageBucket,
        where: b.user_id == ^user_id,
        group_by: b.bucket_start,
        order_by: [desc: b.bucket_start],
        limit: ^max_bars,
        select: b.bucket_start
      )
      |> Repo.all()

    ets_by_token_bucket = ets_counts_by_token_bucket(user_id)

    ets_bucket_times =
      ets_by_token_bucket
      |> Map.keys()
      |> Enum.map(&elem(&1, 1))
      |> Enum.uniq()

    bucket_starts =
      (db_buckets ++ ets_bucket_times)
      |> Enum.uniq()
      |> Enum.sort_by(&DateTime.to_unix(&1, :second))
      |> Enum.take(-max_bars)

    build_stacked_chart(user_id, tokens, bucket_starts, ets_by_token_bucket)
  end

  defp usage_stacked_bar_chart_for_range(user_id, tokens, from_date, to_date) do
    start_dt = date_start_utc(from_date)
    end_exclusive = date_start_utc(Date.add(to_date, 1))
    max_bars = @usage_chart_max_bars_filtered

    db_buckets =
      from(b in ApiTokenUsageBucket,
        where: b.user_id == ^user_id,
        where: b.bucket_start >= ^start_dt and b.bucket_start < ^end_exclusive,
        group_by: b.bucket_start,
        order_by: [asc: b.bucket_start],
        select: b.bucket_start
      )
      |> Repo.all()

    ets_by_token_bucket =
      user_id
      |> ets_counts_by_token_bucket()
      |> ets_in_datetime_range(start_dt, end_exclusive)

    ets_bucket_times =
      ets_by_token_bucket
      |> Map.keys()
      |> Enum.map(&elem(&1, 1))
      |> Enum.uniq()

    bucket_starts =
      (db_buckets ++ ets_bucket_times)
      |> Enum.uniq()
      |> Enum.sort_by(&DateTime.to_unix(&1, :second))
      |> trim_bucket_starts_to_max(max_bars)

    build_stacked_chart(user_id, tokens, bucket_starts, ets_by_token_bucket)
  end

  defp date_start_utc(%Date{} = d) do
    DateTime.new!(d, ~T[00:00:00.000000], "Etc/UTC")
  end

  defp ets_in_datetime_range(ets_map, start_dt, end_exclusive) do
    Enum.filter(ets_map, fn {{_, bucket}, _} ->
      DateTime.compare(bucket, start_dt) != :lt and DateTime.compare(bucket, end_exclusive) == :lt
    end)
    |> Map.new()
  end

  defp trim_bucket_starts_to_max(bucket_starts, max) do
    if length(bucket_starts) <= max do
      bucket_starts
    else
      Enum.drop(bucket_starts, length(bucket_starts) - max)
    end
  end

  defp build_stacked_chart(user_id, tokens, bucket_starts, ets_by_token_bucket) do
    if bucket_starts == [] do
      %{labels: [], datasets: []}
    else
      rows =
        from(b in ApiTokenUsageBucket,
          where: b.user_id == ^user_id,
          where: b.bucket_start in ^bucket_starts,
          select: {b.user_api_token_id, b.bucket_start, b.request_count}
        )
        |> Repo.all()

      db_counts =
        Enum.reduce(rows, %{}, fn {tid, bs, c}, acc ->
          Map.put(acc, {tid, bs}, int_request_count(c))
        end)

      labels = Enum.map(bucket_starts, &format_usage_bucket_label/1)

      datasets =
        tokens
        |> Enum.with_index()
        |> Enum.map(fn {t, i} ->
          data =
            Enum.map(bucket_starts, fn bs ->
              d = Map.get(db_counts, {t.id, bs}, 0)
              e = Map.get(ets_by_token_bucket, {t.id, bs}, 0)
              d + e
            end)

          %{
            label: "#{t.token_prefix}…",
            data: data,
            backgroundColor: token_chart_color(i)
          }
        end)

      %{labels: labels, datasets: datasets}
    end
  end

  defp format_usage_bucket_label(%DateTime{} = dt) do
    dt = DateTime.shift_zone!(dt, "Etc/UTC")

    case bucket_period() do
      :hour -> Calendar.strftime(dt, "%d/%m %H:00")
      :minute -> Calendar.strftime(dt, "%d/%m %H:%M")
    end
  end

  defp token_chart_color(i), do: Enum.at(@token_chart_colors, rem(i, length(@token_chart_colors)))

  defp ets_counts_by_token_bucket(user_id) do
    table = @ets_table

    if :ets.whereis(table) == :undefined do
      %{}
    else
      :ets.tab2list(table)
      |> Enum.filter(fn {{uid, _, _}, _} -> uid == user_id end)
      |> Map.new(fn {{_, tid, bucket}, count} -> {{tid, bucket}, count} end)
    end
  end

  defp ets_inflight_counts_by_token(user_id) do
    table = @ets_table

    if :ets.whereis(table) == :undefined do
      %{}
    else
      :ets.tab2list(table)
      |> Enum.filter(fn {{uid, _, _}, _} -> uid == user_id end)
      |> Enum.reduce(%{}, fn {{_, tid, _}, count}, acc ->
        Map.update(acc, tid, count, &(&1 + count))
      end)
    end
  end

  @doc """
  Increments the counter for this user/token and the current time bucket (non-blocking).
  """
  def increment(user_id, token_id)
      when is_integer(user_id) and is_integer(token_id) do
    bucket = bucket_start(DateTime.utc_now())
    key = {user_id, token_id, bucket}
    table = @ets_table

    if :ets.whereis(table) != :undefined do
      :ets.insert_new(table, {key, 0})
      :ets.update_counter(table, key, {2, 1})
    end

    :ok
  rescue
    ArgumentError ->
      :ok
  end

  @doc """
  Persists all entries whose bucket is strictly before the current open bucket, then deletes
  them from ETS. Returns `{:ok, n_flushed}`.
  """
  def drain_closed_buckets do
    table = @ets_table

    if :ets.whereis(table) == :undefined do
      {:ok, 0}
    else
      cutoff = bucket_start(DateTime.utc_now())
      now = DateTime.utc_now(:microsecond)

      entries =
        :ets.tab2list(table)
        |> Enum.filter(fn {{_, _, bucket}, _} ->
          DateTime.compare(bucket, cutoff) == :lt
        end)

      case Repo.transaction(fn ->
             Enum.each(entries, fn {{user_id, token_id, bucket}, count} ->
               upsert_increment!(user_id, token_id, bucket, count, now)
             end)

             length(entries)
           end) do
        {:ok, n} ->
          Enum.each(entries, fn {{user_id, token_id, bucket}, _} ->
            :ets.delete(table, {user_id, token_id, bucket})
          end)

          {:ok, n}

        {:error, _} = err ->
          err
      end
    end
  end

  defp upsert_increment!(user_id, token_id, bucket_start, increment, now) do
    Repo.query!(
      """
      INSERT INTO api_token_usage_buckets (user_id, user_api_token_id, bucket_start, request_count, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (user_id, user_api_token_id, bucket_start)
      DO UPDATE SET
        request_count = api_token_usage_buckets.request_count + EXCLUDED.request_count,
        updated_at = EXCLUDED.updated_at
      """,
      [user_id, token_id, bucket_start, increment, now, now]
    )
  end
end
