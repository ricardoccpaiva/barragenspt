/**
 * Dam card charts: storage, discharge, and realtime.
 * Listens for phx:dam_chart_series, phx:dam_discharge_series, phx:dam_realtime_chart
 * and draws Chart.js when the dam card is visible.
 */

let chartSeries = null
let dischargeSeries = null
const dischargeChartConfig = [
  { key: "ouput_flow_rate_daily", label: "Caudal descarregado médio diário", color: "#0ea5e9" },
  { key: "tributary_daily_flow", label: "Caudal afluente médio diário", color: "#f59e0b" },
  { key: "effluent_daily_flow", label: "Caudal efluente médio diário", color: "#10b981" },
  { key: "turbocharged_daily_flow", label: "Caudal turbinado médio diário", color: "#8b5cf6" }
]
let realtimeChartPayload = null
const realtimeChartConfig = [
  { key: "volume_armazenado", label: "Volume armazenado (%)", color: "#0ea5e9", yAxisID: "y" },
  { key: "caudal_efluente", label: "Caudal efluente", color: "#10b981", yAxisID: "y1" },
  { key: "caudal_afluente", label: "Caudal afluente", color: "#8b5cf6", yAxisID: "y1" }
]
let damRealtimeChart = null
let damChart = null
let damDischargeChart = null

function toggleSidebar(open) {
  const sidebar = document.getElementById("sidebar")
  const backdrop = document.getElementById("sidebarBackdrop")
  if (open) {
    sidebar.classList.add("open")
    backdrop.classList.remove("hidden")
  } else {
    sidebar.classList.remove("open")
    backdrop.classList.add("hidden")
  }
}

window.addEventListener("phx:dam_chart_series", (e) => {
  const payload = e.detail
  if (payload.merge && payload.series) {
    chartSeries = Object.assign({}, chartSeries || {}, payload.series)
  } else {
    chartSeries = payload.series || null
  }
  if (chartSeries && typeof updateDamChart === "function") updateDamChart(chartSeries)
  window.chartSeries = chartSeries
})

window.addEventListener("phx:dam_discharge_series", (e) => {
  const payload = e.detail
  if (payload.merge && payload.series) {
    dischargeSeries = Object.assign({}, dischargeSeries || {}, payload.series)
  } else {
    dischargeSeries = payload.series || null
  }
  if (dischargeSeries && typeof updateDischargeChart === "function") updateDischargeChart(dischargeSeries)
  window.dischargeSeries = dischargeSeries
})

window.addEventListener("phx:dam_realtime_chart", (e) => {
  realtimeChartPayload = e.detail && e.detail.rows ? e.detail.rows : null
  window.realtimeChartPayload = realtimeChartPayload
  setTimeout(() => {
    if (typeof updateRealtimeChart === "function") updateRealtimeChart(realtimeChartPayload)
  }, 0)
})

function formatTick(v) {
  if (v >= 1e6) return (v / 1e6).toFixed(1).replace(/\.0$/, "") + "M"
  if (v >= 1e3) return (v / 1e3).toFixed(1).replace(/\.0$/, "") + "k"
  return v
}

function updateRealtimeChart(rows) {
  const canvas = document.getElementById("damRealtimeChart")
  if (!canvas || typeof Chart === "undefined") return
  if (damRealtimeChart) {
    damRealtimeChart.destroy()
    damRealtimeChart = null
  }
  if (!Array.isArray(rows) || rows.length === 0) return
  const labels = rows.map((r) => r.data || r["data"])
  const datasets = realtimeChartConfig.map((c) => ({
    label: c.label,
    data: rows.map((r) => r[c.key]),
    borderColor: c.color,
    backgroundColor: c.color + "20",
    tension: 0.35,
    pointRadius: 0,
    borderWidth: 2,
    fill: false,
    yAxisID: c.yAxisID || "y1"
  }))
  damRealtimeChart = new Chart(canvas, {
    type: "line",
    data: { labels, datasets },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        tooltip: {
          enabled: true,
          mode: "index",
          intersect: false,
          backgroundColor: "#fff",
          titleColor: "#334155",
          bodyColor: "#475569",
          borderColor: "#e2e8f0",
          borderWidth: 1
        }
      },
      scales: {
        x: { grid: { display: false }, ticks: { maxTicksLimit: 6, font: { size: 8 } } },
        y: {
          type: "linear",
          position: "left",
          min: 0,
          max: 100,
          grid: { color: "rgba(148,163,184,0.2)" },
          ticks: { font: { size: 8 }, color: "#64748b" }
        },
        y1: {
          type: "linear",
          position: "right",
          grid: { drawOnChartArea: false },
          ticks: { font: { size: 8 }, color: "#64748b", callback: formatTick }
        }
      }
    }
  })
}

function updateDamChart(series) {
  const tw = document.getElementById("timeWindow")
  const canvas = document.getElementById("damChart")
  if (!tw || !canvas || typeof Chart === "undefined") return
  const windowKey = tw.value
  const data = series && series[windowKey]
  if (!data) return
  if (damChart) {
    damChart.destroy()
    damChart = null
  }
  damChart = new Chart(canvas, {
    type: "line",
    data: {
      labels: data.labels,
      datasets: [
        {
          label: "Observado (%)",
          data: data.observed,
          borderColor: "#0ea5e9",
          backgroundColor: "rgba(14,165,233,0.08)",
          tension: 0.35,
          pointRadius: 0,
          borderWidth: 2,
          fill: true
        },
        {
          label: "Média (%)",
          data: data.average,
          borderColor: "#f59e0b",
          tension: 0.35,
          pointRadius: 0,
          borderWidth: 2,
          borderDash: [4, 4]
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        tooltip: {
          enabled: true,
          mode: "index",
          intersect: false,
          backgroundColor: "#fff",
          titleColor: "#334155",
          bodyColor: "#475569",
          borderColor: "#e2e8f0",
          borderWidth: 1
        }
      },
      scales: {
        x: { grid: { display: false }, ticks: { maxTicksLimit: 6 } },
        y: {
          type: "linear",
          position: "left",
          min: 0,
          max: 100,
          grid: { color: "rgba(148,163,184,0.2)" },
          title: { display: false },
          ticks: { maxRotation: 45, minRotation: 45, padding: 2, font: { size: 8 }, color: "#64748b" }
        }
      }
    }
  })
}

function updateDischargeChart(series) {
  const tw = document.getElementById("dischargeTimeWindow") || document.getElementById("timeWindow")
  const canvas = document.getElementById("damDischargeChart")
  if (!tw || !canvas || typeof Chart === "undefined") return
  const windowKey = tw.value
  const data = series && series[windowKey]
  if (!data || !data.labels) return
  if (damDischargeChart) {
    damDischargeChart.destroy()
    damDischargeChart = null
  }
  const datasets = dischargeChartConfig.map((c) => ({
    label: c.label,
    data: data[c.key] || [],
    borderColor: c.color,
    backgroundColor: c.color + "20",
    tension: 0.35,
    pointRadius: 0,
    borderWidth: 2,
    fill: false
  }))
  damDischargeChart = new Chart(canvas, {
    type: "line",
    data: { labels: data.labels, datasets },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        tooltip: {
          enabled: true,
          mode: "index",
          intersect: false,
          backgroundColor: "#fff",
          titleColor: "#334155",
          bodyColor: "#475569",
          borderColor: "#e2e8f0",
          borderWidth: 1
        }
      },
      scales: {
        x: { grid: { display: false }, ticks: { maxTicksLimit: 6, font: { size: 8 } } },
        y: {
          grid: { color: "rgba(148,163,184,0.2)" },
          ticks: { font: { size: 8 }, color: "#64748b", callback: formatTick }
        }
      }
    }
  })
}

document.body.addEventListener("change", (e) => {
  if (e.target.id === "timeWindow") updateDamChart(chartSeries)
  if (e.target.id === "dischargeTimeWindow") updateDischargeChart(dischargeSeries)
})

window.addEventListener("phx:page-loading-stop", () => {
  const el = document.getElementById("damChart")
  if (el && chartSeries && typeof updateDamChart === "function") updateDamChart(chartSeries)
  const elD = document.getElementById("damDischargeChart")
  if (elD && dischargeSeries && typeof updateDischargeChart === "function") updateDischargeChart(dischargeSeries)
  const elR = document.getElementById("damRealtimeChart")
  if (elR && realtimeChartPayload && typeof updateRealtimeChart === "function") updateRealtimeChart(realtimeChartPayload)
})

window.toggleSidebar = toggleSidebar
window.updateDamChart = updateDamChart
window.updateDischargeChart = updateDischargeChart
window.updateRealtimeChart = updateRealtimeChart
window.chartSeries = chartSeries
window.dischargeSeries = dischargeSeries
window.realtimeChartPayload = realtimeChartPayload
