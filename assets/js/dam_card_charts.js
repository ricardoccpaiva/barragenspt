/**
 * Dam card charts: storage, discharge, and realtime.
 * Listens for phx:dam_chart_series, phx:dam_discharge_series, phx:dam_realtime_chart
 * and draws Chart.js when the dam card is visible.
 */

function isDarkMode() {
  return document.documentElement.classList.contains("dark")
}

const chartColors = {
  light: {
    realtime: [
      { key: "volume_armazenado", label: "Volume armazenado (%)", color: "#0ea5e9", yAxisID: "y" },
      { key: "caudal_efluente", label: "Caudal efluente", color: "#10b981", yAxisID: "y1" },
      { key: "caudal_afluente", label: "Caudal afluente", color: "#8b5cf6", yAxisID: "y1" }
    ],
    discharge: [
      { key: "ouput_flow_rate_daily", label: "Caudal descarregado médio diário", color: "#0ea5e9" },
      { key: "tributary_daily_flow", label: "Caudal afluente médio diário", color: "#f59e0b" },
      { key: "effluent_daily_flow", label: "Caudal efluente médio diário", color: "#10b981" },
      { key: "turbocharged_daily_flow", label: "Caudal turbinado médio diário", color: "#8b5cf6" }
    ],
    grid: "rgba(148,163,184,0.2)",
    ticks: "#64748b",
    tooltip: { bg: "#fff", title: "#334155", body: "#475569", border: "#e2e8f0" },
    storage: { observed: "#0ea5e9", average: "#f59e0b" }
  },
  dark: {
    realtime: [
      { key: "volume_armazenado", label: "Volume armazenado (%)", color: "#38bdf8", yAxisID: "y" },
      { key: "caudal_efluente", label: "Caudal efluente", color: "#34d399", yAxisID: "y1" },
      { key: "caudal_afluente", label: "Caudal afluente", color: "#a78bfa", yAxisID: "y1" }
    ],
    discharge: [
      { key: "ouput_flow_rate_daily", label: "Caudal descarregado médio diário", color: "#38bdf8" },
      { key: "tributary_daily_flow", label: "Caudal afluente médio diário", color: "#fbbf24" },
      { key: "effluent_daily_flow", label: "Caudal efluente médio diário", color: "#34d399" },
      { key: "turbocharged_daily_flow", label: "Caudal turbinado médio diário", color: "#a78bfa" }
    ],
    grid: "rgba(148,163,184,0.35)",
    ticks: "#94a3b8",
    tooltip: { bg: "#334155", title: "#f1f5f9", body: "#cbd5e1", border: "#475569" },
    storage: { observed: "#38bdf8", average: "#fbbf24" }
  }
}

let chartSeries = null
let dischargeSeries = null
let realtimeChartPayload = null
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
  const theme = chartColors[isDarkMode() ? "dark" : "light"]
  const config = theme.realtime
  const labels = rows.map((r) => r.data || r["data"])
  const datasets = config.map((c) => ({
    label: c.label,
    data: rows.map((r) => r[c.key]),
    borderColor: c.color,
    backgroundColor: c.color + "30",
    tension: 0.35,
    pointRadius: 0,
    borderWidth: 2,
    fill: false,
    yAxisID: c.yAxisID || "y1"
  }))
  const t = theme.tooltip
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
          backgroundColor: t.bg,
          titleColor: t.title,
          bodyColor: t.body,
          borderColor: t.border,
          borderWidth: 1
        }
      },
      scales: {
        x: { grid: { display: false }, ticks: { maxTicksLimit: 6, font: { size: 8 }, color: theme.ticks } },
        y: {
          type: "linear",
          position: "left",
          min: 0,
          max: 100,
          grid: { color: theme.grid },
          ticks: { font: { size: 8 }, color: theme.ticks }
        },
        y1: {
          type: "linear",
          position: "right",
          grid: { drawOnChartArea: false },
          ticks: { font: { size: 8 }, color: theme.ticks, callback: formatTick }
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
  const theme = chartColors[isDarkMode() ? "dark" : "light"]
  const s = theme.storage
  const t = theme.tooltip
  damChart = new Chart(canvas, {
    type: "line",
    data: {
      labels: data.labels,
      datasets: [
        {
          label: "Observado (%)",
          data: data.observed,
          borderColor: s.observed,
          backgroundColor: s.observed + "20",
          tension: 0.35,
          pointRadius: 0,
          borderWidth: 2,
          fill: true
        },
        {
          label: "Média (%)",
          data: data.average,
          borderColor: s.average,
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
          backgroundColor: t.bg,
          titleColor: t.title,
          bodyColor: t.body,
          borderColor: t.border,
          borderWidth: 1
        }
      },
      scales: {
        x: { grid: { display: false }, ticks: { maxTicksLimit: 6, color: theme.ticks } },
        y: {
          type: "linear",
          position: "left",
          min: 0,
          max: 100,
          grid: { color: theme.grid },
          title: { display: false },
          ticks: { maxRotation: 45, minRotation: 45, padding: 2, font: { size: 8 }, color: theme.ticks }
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
  const theme = chartColors[isDarkMode() ? "dark" : "light"]
  const config = theme.discharge
  const datasets = config.map((c) => ({
    label: c.label,
    data: data[c.key] || [],
    borderColor: c.color,
    backgroundColor: c.color + "30",
    tension: 0.35,
    pointRadius: 0,
    borderWidth: 2,
    fill: false
  }))
  const t = theme.tooltip
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
          backgroundColor: t.bg,
          titleColor: t.title,
          bodyColor: t.body,
          borderColor: t.border,
          borderWidth: 1
        }
      },
      scales: {
        x: { grid: { display: false }, ticks: { maxTicksLimit: 6, font: { size: 8 }, color: theme.ticks } },
        y: {
          grid: { color: theme.grid },
          ticks: { font: { size: 8 }, color: theme.ticks, callback: formatTick }
        }
      }
    }
  })
}

document.body.addEventListener("change", (e) => {
  if (e.target.id === "timeWindow") updateDamChart(chartSeries)
  if (e.target.id === "dischargeTimeWindow") updateDischargeChart(dischargeSeries)
})

window.addEventListener("dark-mode-change", () => {
  if (chartSeries && typeof updateDamChart === "function") updateDamChart(chartSeries)
  if (dischargeSeries && typeof updateDischargeChart === "function") updateDischargeChart(dischargeSeries)
  if (realtimeChartPayload && typeof updateRealtimeChart === "function") updateRealtimeChart(realtimeChartPayload)
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
