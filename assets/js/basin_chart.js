let basinChart = null;
let basinChartSeriesKey = null;

function getBasinChartSeries(canvas) {
  try {
    return JSON.parse(canvas.dataset.series || "[]");
  } catch (_) {
    return [];
  }
}

function formatBasinChartLabel(isoDate) {
  const date = new Date(isoDate);
  if (Number.isNaN(date.getTime())) return isoDate;
  return date.toLocaleDateString("pt-PT", { month: "short", year: "2-digit" });
}

function formatBasinTooltipDate(isoDate) {
  const date = new Date(isoDate);
  if (Number.isNaN(date.getTime())) return isoDate;
  return date.toLocaleDateString("pt-PT", { day: "2-digit", month: "short", year: "numeric" });
}

function renderBasinChart() {
  const canvas = document.getElementById("basinChart");
  if (!canvas || typeof Chart === "undefined") return;

  const series = getBasinChartSeries(canvas);
  const seriesKey = JSON.stringify(series);

  if (basinChart && basinChartSeriesKey === seriesKey) return;
  if (basinChart) basinChart.destroy();
  basinChartSeriesKey = seriesKey;

  const labels = series.map((point) => formatBasinChartLabel(point.date));
  const observed = series.map((point) => point.observed_value);
  const average = series.map((point) => point.historical_average);

  basinChart = new Chart(canvas, {
    type: "line",
    data: {
      labels,
      datasets: [
        {
          label: "Observado",
          data: observed,
          borderColor: "#0ea5e9",
          backgroundColor: "rgba(14,165,233,0.12)",
          tension: 0.35,
          pointRadius: 0,
          pointHoverRadius: 0,
          borderWidth: 2,
          fill: true
        },
        {
          label: "Média",
          data: average,
          borderColor: "#f59e0b",
          borderDash: [4, 4],
          tension: 0.35,
          pointRadius: 0,
          pointHoverRadius: 0,
          borderWidth: 2
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
          backgroundColor: "rgba(255, 255, 255, 0.96)",
          titleColor: "#0f172a",
          bodyColor: "#334155",
          borderColor: "rgba(148, 163, 184, 0.35)",
          borderWidth: 1,
          displayColors: true,
          boxPadding: 4,
          padding: 10,
          callbacks: {
            title(items) {
              if (!items || !items.length) return "";
              const index = items[0].dataIndex;
              const point = series[index];
              return point ? formatBasinTooltipDate(point.date) : "";
            }
          }
        }
      },
      scales: {
        x: { grid: { display: false } },
        y: {
          min: 0,
          max: 100,
          grid: { color: "rgba(148,163,184,0.2)" }
        }
      }
    }
  });
}

function selectBasinTab(tab) {
  const table = document.getElementById("basinTabTable");
  const chart = document.getElementById("basinTabChart");
  const buttons = document.querySelectorAll("[data-basin-tab]");

  buttons.forEach((btn) => {
    const active = btn.getAttribute("data-basin-tab") === tab;
    btn.classList.toggle("bg-white", active);
    btn.classList.toggle("text-slate-700", active);
    btn.classList.toggle("shadow-sm", active);
    btn.classList.toggle("text-slate-600", !active);
  });

  if (tab === "chart") {
    if (table) table.classList.add("hidden");
    if (chart) chart.classList.remove("hidden");
    renderBasinChart();
    return;
  }

  if (chart) chart.classList.add("hidden");
  if (table) table.classList.remove("hidden");
}

window.selectBasinTab = selectBasinTab;

