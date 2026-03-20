defmodule Barragenspt.Workers.EvaluateAlertsTest do
  use Barragenspt.DataCase, async: false

  alias Barragenspt.AccountsFixtures
  alias Barragenspt.Models.Hydrometrics.{Dam, DataPointRealtime}
  alias Barragenspt.Notifications
  alias Barragenspt.Notifications.{AlertEvent, UserAlert}
  alias Barragenspt.Repo
  alias Barragenspt.Workers.EvaluateAlerts

  setup do
    Barragenspt.RealtimeDataPointsCache.flush()
    :ok
  end

  test "fires and persists realtime metric alert with once_per_event suppression" do
    user = AccountsFixtures.user_fixture()
    site_id = "site_eval_rt_1"
    insert_dam(site_id)

    Repo.insert!(%DataPointRealtime{
      site_id: site_id,
      basin_id: "20",
      dam_code: "DAMEVAL",
      param_id: "3",
      param_name: "cota",
      value: Decimal.new("101.3"),
      colected_at: ~N[2026-03-20 10:00:00]
    })

    {:ok, alert} =
      Notifications.create_alert(%{
        user_id: user.id,
        subject_type: "dam",
        subject_id: site_id,
        subject_name: "Dam Eval",
        metric: "realtime_level",
        operator: "gt",
        threshold: 100.0,
        repeat_mode: "once_per_event",
        cooldown_hours: 24,
        active: true
      })

    assert :ok = EvaluateAlerts.perform(%Oban.Job{attempt: 1, args: %{"id" => "test-1"}})
    assert Repo.aggregate(from(e in AlertEvent, where: e.alert_id == ^alert.id), :count) == 1

    updated = Repo.get!(UserAlert, alert.id)
    assert updated.breach_notification_sent == true
    assert not is_nil(updated.last_notified_at)

    assert :ok = EvaluateAlerts.perform(%Oban.Job{attempt: 1, args: %{"id" => "test-2"}})
    assert Repo.aggregate(from(e in AlertEvent, where: e.alert_id == ^alert.id), :count) == 1
  end

  defp insert_dam(site_id) do
    Repo.insert!(%Dam{
      site_id: site_id,
      code: "DAM#{site_id}",
      name: "Dam #{site_id}",
      basin: "Bacia Teste",
      basin_id: "20",
      metadata: %{"test" => true},
      total_capacity: 1000
    })
  end
end
