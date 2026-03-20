defmodule Barragenspt.Notifications.AlertMetricsTest do
  use Barragenspt.DataCase, async: false

  alias Barragenspt.Notifications.AlertMetrics
  alias Barragenspt.Models.Hydrometrics.{Dam, DataPointRealtime}
  alias Barragenspt.Repo

  setup do
    Barragenspt.RealtimeDataPointsCache.flush()
    :ok
  end

  test "returns latest realtime value for dam metric" do
    site_id = "site_realtime_1"
    insert_dam(site_id)

    old_time = ~N[2026-03-20 09:00:00]
    new_time = ~N[2026-03-20 09:10:00]

    Repo.insert!(%DataPointRealtime{
      site_id: site_id,
      basin_id: "13",
      dam_code: "DAM13",
      param_id: "6",
      param_name: "caudal_afluente",
      value: Decimal.new("10.5"),
      colected_at: old_time
    })

    Repo.insert!(%DataPointRealtime{
      site_id: site_id,
      basin_id: "13",
      dam_code: "DAM13",
      param_id: "6",
      param_name: "caudal_afluente",
      value: Decimal.new("12.7"),
      colected_at: new_time
    })

    value =
      AlertMetrics.current_value(%{
        subject_type: "dam",
        subject_id: site_id,
        metric: "realtime_inflow"
      })

    assert value == 12.7
  end

  test "returns nil for realtime metric on non-dam subject" do
    value =
      AlertMetrics.current_value(%{
        subject_type: "national",
        subject_id: nil,
        metric: "realtime_inflow"
      })

    assert value == nil
  end

  defp insert_dam(site_id) do
    Repo.insert!(%Dam{
      site_id: site_id,
      code: "DAM#{site_id}",
      name: "Dam #{site_id}",
      basin: "Bacia Teste",
      basin_id: "13",
      metadata: %{"test" => true},
      total_capacity: 1000
    })
  end
end
