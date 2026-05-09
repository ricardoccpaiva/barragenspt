import topbar from "../vendor/topbar"
import { getStorageColor, DAMS_CIRCLE_COLOR_GRAY } from "./utils/colors"

const MINI_MAP_LIGHT_STYLE = "https://mapas.barragens.pt/styles/klokantech-basic/style.json"
const MINI_MAP_DARK_STYLE = "https://mapas.barragens.pt/styles/positron/style.json"

function getMap() {
  return window.map
}

function applyCapacityColor(el) {
  const pct = el.dataset.observed
  el.style.backgroundColor = (pct !== "" && pct !== undefined && !Number.isNaN(Number(pct)))
    ? getStorageColor(Number(pct))
    : DAMS_CIRCLE_COLOR_GRAY
}

const CapacityColor = {
  mounted() { applyCapacityColor(this.el) },
  updated() { applyCapacityColor(this.el) }
}

const BasinChartTimeWindow = {
  mounted() {
    this.el.addEventListener("click", () => this.pushEvent("basin_change_window", { value: this.el.value }))
    this.el.addEventListener("input", () => this.pushEvent("basin_change_window", { value: this.el.value }))
  }
}

const DamChartTimeWindow = {
  mounted() {
    this.el.addEventListener("change", () => {
      const target = this.el.getAttribute?.("phx-target") ?? this.el.getAttribute?.("data-phx-target") ?? this.el.dataset?.phxTarget
      const payload = { value: this.el.value }
      if (target !== undefined && target !== null && target !== "") {
        this.pushEventTo(parseInt(target, 10), "dam_change_window", payload)
      } else {
        this.pushEvent("dam_change_window", payload)
      }
    })
  }
}

const DamChartMount = {
  mounted() {
    if (typeof window.updateDamChart === "function" && window.chartSeries) {
      window.updateDamChart(window.chartSeries)
    }
  }
}

const DischargeChartMount = {
  mounted() {
    if (typeof window.updateDischargeChart === "function" && window.dischargeSeries) {
      window.updateDischargeChart(window.dischargeSeries)
    }
  }
}

const DamRealtimeChartMount = {
  mounted() {
    setTimeout(() => {
      if (typeof window.updateRealtimeChart === "function" && window.realtimeChartPayload) {
        window.updateRealtimeChart(window.realtimeChartPayload)
      }
    }, 50)
  }
}

const RiverChanged = {
  mounted() {
    this.el.addEventListener("input", () => {
      topbar.show()
      const codes = this.el.value.split("_")
      const map = getMap()
      if (codes.length === 2) {
        this.pushEvent("select_river", { basin_id: codes[1], river_name: codes[0] })
      } else {
        this.pushEvent("select_river", {})
        if (map && map.getStyle && map.getStyle().layers) {
          map.getStyle().layers.forEach((item) => {
            if (item.id.includes("rio_") && item.id.includes("_outline")) map.removeLayer(item.id)
            else if (item.id.includes("rio_")) map.removeSource(item.id)
          })
        }
      }
    })
  }
}

const UsageTypeChanged = {
  mounted() {
    this.el.addEventListener("change", (e) => {
      topbar.show()
      const usageType = e.target.name
      const checked = e.target.checked
      gtagEvent("usage_type_filter", { type: usageType, state: checked ? "on" : "off" })
      this.pushEvent("update_selected_usage_types", { usage_type: usageType, checked })
    })
  }
}

function gtagEvent(name, params) {
  if (typeof gtag === "function") gtag("event", name, params)
}

const SearchDam = {
  mounted() {
    this.el.addEventListener("input", () => this.pushEvent("search_dam", { search_term: this.el.value }))

    const resultsContainer = document.getElementById("damSearchResults")
    if (resultsContainer) {
      resultsContainer.addEventListener("click", (e) => {
        const riverBtn = e.target.closest("button[data-river-name]")
        if (riverBtn) {
          gtagEvent("select_river", { river_name: riverBtn.dataset.riverName })
          return
        }
        const damLink = e.target.closest("a[data-phx-link]")
        if (damLink) {
          const nameEl = damLink.querySelector("span:first-child")
          gtagEvent("select_dam", { dam_name: nameEl ? nameEl.textContent.trim() : "" })
        }
      })
    }
  }
}

/** Client-side filter for dashboard data-points dam multi-select list (no LiveView round-trip). */
const DamMultiselectSearch = {
  mounted() {
    this.panelId = this.el.dataset.msPanel
    this.onInput = () => {
      const q = this.el.value.trim().toLowerCase()
      const panel = this.panelId && document.getElementById(this.panelId)
      if (!panel) return
      panel.querySelectorAll("[data-ms-filter-text], [data-ms-dam]").forEach((el) => {
        const hay =
          (el.getAttribute("data-ms-filter-text") || el.getAttribute("data-ms-dam") || "").toLowerCase()
        el.classList.toggle("hidden", q !== "" && !hay.includes(q))
      })
    }
    this.el.addEventListener("input", this.onInput)
  },
  destroyed() {
    this.el.removeEventListener("input", this.onInput)
  }
}

const DarkModeToggle = {
  mounted() {
    const el = this.el
    const lightBtn = el.querySelector('[data-theme-option="light"]')
    const darkBtn = el.querySelector('[data-theme-option="dark"]')

    const activeThemeBtn = [
      "bg-brand-100",
      "text-brand-800",
      "ring-1",
      "ring-inset",
      "ring-brand-400/70",
      "shadow-sm",
      "dark:bg-brand-900/70",
      "dark:text-brand-100",
      "dark:ring-brand-400/50"
    ]
    const inactiveThemeBtn = ["text-slate-500", "dark:text-slate-400"]

    const setButtonState = (button, active) => {
      if (!button) return
      button.setAttribute("aria-pressed", active ? "true" : "false")
      activeThemeBtn.forEach((c) => button.classList.toggle(c, active))
      inactiveThemeBtn.forEach((c) => button.classList.toggle(c, !active))
    }

    const syncState = (on) => {
      setButtonState(lightBtn, !on)
      setButtonState(darkBtn, on)
    }

    syncState(document.documentElement.classList.contains("dark"))

    this.onClick = (event) => {
      const option = event.target.closest("[data-theme-option]")
      if (!option || !el.contains(option)) return

      const on = option.dataset.themeOption === "dark"
      gtagEvent("toggle_dark_mode", { state: on ? "on" : "off" })
      document.documentElement.classList.toggle("dark", on)
      try { localStorage.setItem("darkMode", on ? "1" : "0") } catch (e) { }
      syncState(on)
      window.dispatchEvent(new CustomEvent("dark-mode-change", { detail: { dark: on } }))
    }

    el.addEventListener("click", this.onClick)
  },

  destroyed() {
    this.el.removeEventListener("click", this.onClick)
  }
}

const AvatarMenu = {
  mounted() {
    this.onDocumentClick = (event) => {
      if (this.el.hasAttribute("open") && !this.el.contains(event.target)) {
        this.el.removeAttribute("open")
      }
    }

    this.onDocumentKeydown = (event) => {
      if (event.key === "Escape" && this.el.hasAttribute("open")) {
        this.el.removeAttribute("open")
      }
    }

    document.addEventListener("click", this.onDocumentClick)
    document.addEventListener("keydown", this.onDocumentKeydown)
  },

  destroyed() {
    document.removeEventListener("click", this.onDocumentClick)
    document.removeEventListener("keydown", this.onDocumentKeydown)
  }
}

const NavRouteActive = {
  mounted() {
    this.markActive = () => {
      const pathname = window.location.pathname || "/"
      this.el.querySelectorAll("[data-nav-path]").forEach((link) => {
        const target = link.getAttribute("data-nav-path") || "/"
        const active = target === "/" ? pathname === "/" : (pathname === target || pathname.startsWith(target + "/"))

        const activeNav = [
          "bg-brand-100",
          "text-brand-800",
          "ring-1",
          "ring-inset",
          "ring-brand-400/70",
          "shadow-sm",
          "dark:bg-brand-900/65",
          "dark:text-brand-100",
          "dark:ring-brand-400/45"
        ]
        const mutedNav = ["text-slate-500", "dark:text-slate-400"]
        activeNav.forEach((c) => link.classList.toggle(c, active))
        mutedNav.forEach((c) => link.classList.toggle(c, !active))

        if (active) {
          link.setAttribute("aria-current", "page")
        } else {
          link.removeAttribute("aria-current")
        }
      })
    }

    this.toggleSidebar = (open) => {
      const sidebar = document.getElementById("app-shell-sidebar")
      const backdrop = document.getElementById("app-shell-backdrop")
      if (!sidebar || !backdrop) return
      sidebar.classList.toggle("-translate-x-[calc(100%+1rem)]", !open)
      backdrop.classList.toggle("hidden", !open)
    }

    window.toggleAppShellSidebar = this.toggleSidebar
    this.markActive()
    window.addEventListener("popstate", this.markActive)
    window.addEventListener("phx:page-loading-stop", this.markActive)
  },

  destroyed() {
    window.removeEventListener("popstate", this.markActive)
    window.removeEventListener("phx:page-loading-stop", this.markActive)
  }
}

const BasinMiniMap = {
  mounted() {
    this.map = null
    this.styleLoaded = false
    this.initMap()
  },

  updated() {
    this.applyData()
  },

  destroyed() {
    if (this.map) {
      this.map.remove()
      this.map = null
    }
  },

  initMap() {
    const maplibre = window.maplibregl
    if (!maplibre || !this.el) return

    this.map = new maplibre.Map({
      container: this.el,
      interactive: false,
      attributionControl: false,
      style: document.documentElement.classList.contains("dark") ? MINI_MAP_DARK_STYLE : MINI_MAP_LIGHT_STYLE
    })

    this.map.once("load", () => {
      this.styleLoaded = true
      this.applyData()
    })
  },

  parseJson(value) {
    if (!value) return null
    try {
      return JSON.parse(value)
    } catch (_) {
      return null
    }
  },

  applyData() {
    if (!this.map || !this.styleLoaded) return

    const basinGeojson = this.parseJson(this.el.dataset.basinGeojson)
    const contextGeojson = this.parseJson(this.el.dataset.contextGeojson)
    const damsGeojson = this.parseJson(this.el.dataset.damsGeojson)
    const fitBounds = this.parseJson(this.el.dataset.fitBounds)

    if (contextGeojson) {
      const contextSource = this.map.getSource("mini-context-basins")
      if (contextSource) contextSource.setData(contextGeojson)
      else this.map.addSource("mini-context-basins", { type: "geojson", data: contextGeojson })

      if (!this.map.getLayer("mini-context-basins-fill")) {
        this.map.addLayer({
          id: "mini-context-basins-fill",
          type: "fill",
          source: "mini-context-basins",
          paint: {
            "fill-color": "#cbd5e1",
            "fill-opacity": 0.35
          }
        })
      }

      if (!this.map.getLayer("mini-context-basins-outline")) {
        this.map.addLayer({
          id: "mini-context-basins-outline",
          type: "line",
          source: "mini-context-basins",
          paint: {
            "line-color": "#ffffff",
            "line-width": 1.1,
            "line-opacity": 0.9
          }
        })
      }
    }

    if (basinGeojson) {
      const basinSource = this.map.getSource("mini-basin")
      if (basinSource) basinSource.setData(basinGeojson)
      else this.map.addSource("mini-basin", { type: "geojson", data: basinGeojson })

      if (!this.map.getLayer("mini-basin-fill")) {
        this.map.addLayer({
          id: "mini-basin-fill",
          type: "fill",
          source: "mini-basin",
          paint: {
            "fill-color": ["coalesce", ["get", "fill_color"], "#38a3ff"],
            "fill-opacity": 0.84
          }
        })
      }

      if (!this.map.getLayer("mini-basin-outline")) {
        this.map.addLayer({
          id: "mini-basin-outline",
          type: "line",
          source: "mini-basin",
          paint: {
            "line-color": "#334155",
            "line-width": 1.4,
            "line-opacity": 0.8
          }
        })
      }
    }

    if (damsGeojson) {
      const damsSource = this.map.getSource("mini-dams")
      if (damsSource) damsSource.setData(damsGeojson)
      else this.map.addSource("mini-dams", { type: "geojson", data: damsGeojson })

      if (!this.map.getLayer("mini-dams-points")) {
        this.map.addLayer({
          id: "mini-dams-points",
          type: "circle",
          source: "mini-dams",
          paint: {
            "circle-radius": 6,
            "circle-color": ["coalesce", ["get", "color"], "#94a3b8"],
            "circle-stroke-color": "#ffffff",
            "circle-stroke-width": 3
          }
        })
      }
    }

    if (Array.isArray(fitBounds) && fitBounds.length === 2) {
      this.map.resize()
      this.map.fitBounds(fitBounds, {
        padding: 16,
        duration: 0,
        maxZoom: 10
      })
    }
  }
}

const StorageReportPortugalMap = {
  mounted() {
    this.map = null
    this.styleLoaded = false
    this.initMap()
  },

  updated() {
    this.applyData()
  },

  destroyed() {
    if (this.map) {
      this.map.remove()
      this.map = null
    }
  },

  initMap() {
    const maplibre = window.maplibregl
    if (!maplibre || !this.el) return

    this.map = new maplibre.Map({
      container: this.el,
      interactive: false,
      attributionControl: false,
      style: document.documentElement.classList.contains("dark") ? MINI_MAP_DARK_STYLE : MINI_MAP_LIGHT_STYLE
    })

    this.map.once("load", () => {
      this.styleLoaded = true
      this.applyData()
    })
  },

  parseJson(value) {
    if (!value) return null
    try {
      return JSON.parse(value)
    } catch (_) {
      return null
    }
  },

  applyData() {
    if (!this.map || !this.styleLoaded) return

    const basinsGeojson = this.parseJson(this.el.dataset.basinsGeojson)
    const damsGeojson = this.parseJson(this.el.dataset.damsGeojson)
    const fitBounds = this.parseJson(this.el.dataset.fitBounds)

    if (basinsGeojson) {
      const source = this.map.getSource("storage-report-basins")
      if (source) source.setData(basinsGeojson)
      else this.map.addSource("storage-report-basins", { type: "geojson", data: basinsGeojson })

      if (!this.map.getLayer("storage-report-basins-fill")) {
        this.map.addLayer({
          id: "storage-report-basins-fill",
          type: "fill",
          source: "storage-report-basins",
          paint: {
            "fill-color": ["coalesce", ["get", "fill_color"], "#cbd5e1"],
            "fill-opacity": ["coalesce", ["get", "fill_opacity"], 0.45]
          }
        })
      }

      if (!this.map.getLayer("storage-report-basins-outline")) {
        this.map.addLayer({
          id: "storage-report-basins-outline",
          type: "line",
          source: "storage-report-basins",
          paint: {
            "line-color": "#ffffff",
            "line-width": 1.0,
            "line-opacity": 0.9
          }
        })
      }
    }

    if (damsGeojson) {
      const damsSource = this.map.getSource("storage-report-dams")
      if (damsSource) damsSource.setData(damsGeojson)
      else this.map.addSource("storage-report-dams", { type: "geojson", data: damsGeojson })

      if (!this.map.getLayer("storage-report-dams-points")) {
        this.map.addLayer({
          id: "storage-report-dams-points",
          type: "circle",
          source: "storage-report-dams",
          paint: {
            "circle-radius": 5,
            "circle-color": ["coalesce", ["get", "color"], "#94a3b8"],
            "circle-stroke-color": "#ffffff",
            "circle-stroke-width": 2
          }
        })
      }
    }

    if (Array.isArray(fitBounds) && fitBounds.length === 2) {
      this.map.resize()
      this.map.fitBounds(fitBounds, {
        padding: 20,
        duration: 0,
        maxZoom: 8
      })
    }
  }
}

const StorageReportPdfExport = {
  mounted() {
    this.label = this.el.querySelector("[data-export-label]")
    this.spinner = this.el.querySelector("[data-export-spinner]")
    this.resetTimer = null
    this.reset = this.reset.bind(this)

    this.el.addEventListener("click", () => {
      this.setLoading()
      this.resetTimer = window.setTimeout(this.reset, 15000)
    })

    window.addEventListener("pageshow", this.reset)
    window.addEventListener("focus", this.reset)
  },

  destroyed() {
    if (this.resetTimer) window.clearTimeout(this.resetTimer)
    window.removeEventListener("pageshow", this.reset)
    window.removeEventListener("focus", this.reset)
  },

  setLoading() {
    if (this.label) this.label.textContent = "A exportar..."
    if (this.spinner) this.spinner.classList.remove("hidden")

    this.el.setAttribute("aria-busy", "true")
    this.el.classList.add("pointer-events-none", "opacity-75")
  },

  reset() {
    if (this.resetTimer) {
      window.clearTimeout(this.resetTimer)
      this.resetTimer = null
    }

    if (this.label) this.label.textContent = "Exportar PDF"
    if (this.spinner) this.spinner.classList.add("hidden")

    this.el.removeAttribute("aria-busy")
    this.el.classList.remove("pointer-events-none", "opacity-75")
  }
}

const OpenSettingsModal = {
  mounted() {
    this.el.addEventListener("click", () => {
      gtagEvent("open_modal", { modal: "settings" })
    })
  }
}

const SettingsModalBackdrop = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      if (e.target === this.el) this.pushEvent("close_settings_modal", {})
    })
  }
}

const SettingsModalCloseButton = {
  mounted() {
    this.el.addEventListener("click", () => this.pushEvent("close_settings_modal", {}))
  }
}

const ContactForm = {
  mounted() {
    this.el.addEventListener("submit", () => {
      gtagEvent("contact_form_submit")
    })
  }
}

const OpenContactModal = {
  mounted() {
    this.el.addEventListener("click", () => {
      gtagEvent("open_modal", { modal: "contact" })
      const backdrop = document.getElementById("contact-modal-backdrop")
      if (backdrop) backdrop.classList.remove("hidden")
    })
  }
}

const ContactModalBackdrop = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      if (e.target === this.el) this.el.classList.add("hidden")
    })
  }
}

const ContactModalCloseButton = {
  mounted() {
    this.el.addEventListener("click", () => {
      const backdrop = document.getElementById("contact-modal-backdrop")
      if (backdrop) backdrop.classList.add("hidden")
    })
  }
}

const OpenInfoModal = {
  mounted() {
    this.el.addEventListener("click", () => {
      gtagEvent("open_modal", { modal: "info" })
      const backdrop = document.getElementById("info-modal-backdrop")
      if (backdrop) backdrop.classList.remove("hidden")
    })
  }
}

const InfoModalBackdrop = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      if (e.target === this.el) this.el.classList.add("hidden")
    })
  }
}

const InfoModalCloseButton = {
  mounted() {
    this.el.addEventListener("click", () => {
      const backdrop = document.getElementById("info-modal-backdrop")
      if (backdrop) backdrop.classList.add("hidden")
    })
  }
}

const ExportDamCard = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.preventDefault()
      const card = document.getElementById("damCard")
      if (!card || typeof window.html2canvas !== "function") return
      const filename = (this.el.dataset.damName || "barragem").replace(/\s+/g, "-") + ".png"
      window.html2canvas(card, {
        scale: 2,
        useCORS: true,
        logging: false,
        backgroundColor: null
      }).then((canvas) => {
        const link = document.createElement("a")
        link.download = filename
        link.href = canvas.toDataURL("image/png")
        link.click()
      })
    })
  }
}

const ApiTokensUsageChart = {
  mounted() {
    this.chart = null
    this._lastFingerprint = null

    this.handleEvent("api-tokens-usage-chart", (payload) => {
      this.applyUsageChartPayload(payload)
    })
  },

  destroyed() {
    this._lastFingerprint = null
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  },

  applyUsageChartPayload(payload) {
    if (typeof window.Chart === "undefined") return

    const canvas = this.el.querySelector("canvas")
    if (!canvas) return

    const labels = (payload && payload.labels) || []
    const datasetsIn = (payload && payload.datasets) || []

    if (labels.length === 0 || datasetsIn.length === 0) {
      if (this.chart) {
        this.chart.destroy()
        this.chart = null
      }
      return
    }

    let fingerprint
    try {
      fingerprint = JSON.stringify(payload)
    } catch (_) {
      return
    }

    if (
      fingerprint === this._lastFingerprint &&
      this.chart &&
      this.chart.canvas === canvas &&
      canvas.isConnected
    ) {
      return
    }

    this._lastFingerprint = fingerprint

    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }

    const isDark = document.documentElement.classList.contains("dark")
    const tickColor = isDark ? "#94a3b8" : "#64748b"
    const gridColor = isDark ? "rgba(148, 163, 184, 0.14)" : "rgba(100, 116, 139, 0.18)"

    this.chart = new window.Chart(canvas, {
      type: "bar",
      data: {
        labels,
        datasets: datasetsIn.map((ds) => ({
          label: ds.label,
          data: ds.data,
          backgroundColor: ds.backgroundColor,
          borderRadius: 4,
          borderSkipped: false,
          stack: "usage"
        }))
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: { duration: 0 },
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: {
            position: "bottom",
            labels: { color: tickColor, boxWidth: 12, padding: 10 }
          },
          tooltip: {
            mode: "index",
            intersect: false,
            backgroundColor: isDark ? "#1e293b" : "#fff",
            titleColor: tickColor,
            bodyColor: tickColor,
            borderColor: gridColor,
            borderWidth: 1
          }
        },
        scales: {
          x: {
            stacked: true,
            ticks: { color: tickColor, maxRotation: 45, autoSkip: true, maxTicksLimit: 16 },
            grid: { color: gridColor }
          },
          y: {
            stacked: true,
            beginAtZero: true,
            ticks: { color: tickColor, precision: 0 },
            grid: { color: gridColor }
          }
        }
      }
    })

    requestAnimationFrame(() => {
      if (this.chart) this.chart.resize()
    })
  }
}

const DataPointsChart = {
  mounted() {
    this.chart = null
    this.canvas = this.el.querySelector("canvas")
    if (!this.canvas) return

    this.handleEvent("data-points-chart-data", (payload) => {
      if (typeof window.Chart === "undefined") return

      const chart = payload && payload.chart
      if (this.chart) {
        this.chart.destroy()
        this.chart = null
      }
      if (!chart || !this.canvas) return

      const labels = chart.labels || []
      const datasets = chart.datasets || []
      if (labels.length === 0 || datasets.length === 0) return

      const isDark = document.documentElement.classList.contains("dark")
      const tickColor = isDark ? "#94a3b8" : "#64748b"
      const gridColor = isDark ? "rgba(148, 163, 184, 0.14)" : "rgba(100, 116, 139, 0.18)"

      this.chart = new window.Chart(this.canvas, {
        type: "line",
        data: {
          labels,
          datasets: datasets.map((ds) => ({
            ...ds,
            fill: false,
            pointRadius: 0,
            pointHoverRadius: 0
          }))
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          interaction: { mode: "index", intersect: false },
          plugins: {
            legend: {
              position: "bottom",
              labels: { color: tickColor, boxWidth: 12, padding: 12 }
            }
          },
          scales: {
            x: {
              type: "category",
              ticks: { color: tickColor, maxRotation: 45, autoSkip: true, maxTicksLimit: 14 },
              grid: { color: gridColor }
            },
            y: {
              ticks: { color: tickColor },
              grid: { color: gridColor }
            }
          }
        }
      })
    })
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }
}

const AdminProductChart = {
  mounted() {
    this.chart = null
    this._lastFingerprint = null

    this.handleEvent("admin-product-chart", (payload) => {
      this.applyPayload(payload)
    })
  },

  destroyed() {
    this._lastFingerprint = null
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  },

  applyPayload(payload) {
    if (typeof window.Chart === "undefined") return

    const canvas = this.el.querySelector("canvas")
    if (!canvas) return

    const labels = (payload && payload.labels) || []
    const datasetsIn = (payload && payload.datasets) || []

    if (labels.length === 0 || datasetsIn.length === 0) {
      if (this.chart) {
        this.chart.destroy()
        this.chart = null
      }
      return
    }

    let fingerprint
    try {
      fingerprint = JSON.stringify(payload)
    } catch (_) {
      return
    }

    if (
      fingerprint === this._lastFingerprint &&
      this.chart &&
      this.chart.canvas === canvas &&
      canvas.isConnected
    ) {
      return
    }

    this._lastFingerprint = fingerprint

    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }

    const isDark = document.documentElement.classList.contains("dark")
    const tickColor = isDark ? "#94a3b8" : "#64748b"
    const gridColor = isDark ? "rgba(148, 163, 184, 0.14)" : "rgba(100, 116, 139, 0.18)"

    this.chart = new window.Chart(canvas, {
      type: "bar",
      data: {
        labels,
        datasets: datasetsIn.map((ds) => ({
          ...ds,
          borderRadius: 4,
          borderSkipped: false
        }))
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: { duration: 0 },
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: {
            position: "bottom",
            labels: { color: tickColor, boxWidth: 12, padding: 10 }
          },
          tooltip: {
            mode: "index",
            intersect: false,
            backgroundColor: isDark ? "#1e293b" : "#fff",
            titleColor: tickColor,
            bodyColor: tickColor,
            borderColor: gridColor,
            borderWidth: 1
          }
        },
        scales: {
          x: {
            ticks: { color: tickColor, maxRotation: 45, autoSkip: true, maxTicksLimit: 16 },
            grid: { color: gridColor }
          },
          y: {
            beginAtZero: true,
            ticks: { color: tickColor, precision: 0 },
            grid: { color: gridColor }
          }
        }
      }
    })

    requestAnimationFrame(() => {
      if (this.chart) this.chart.resize()
    })
  }
}

const CopyButton = {
  mounted() {
    this.el.addEventListener("click", async (e) => {
      e.preventDefault()
      const text = this.el.getAttribute("data-copy-text")
      if (!text || !navigator.clipboard) return
      try {
        await navigator.clipboard.writeText(text)
      } catch (_) {}
    })
  }
}

const ExportBasinCard = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.preventDefault()
      const panelId = this.el.dataset.exportTarget || "basinInfoPanel"
      const card = document.getElementById(panelId)
      if (!card || typeof window.html2canvas !== "function") return
      const filename = (this.el.dataset.basinName || "bacia").replace(/\s+/g, "-") + ".png"
      window.html2canvas(card, {
        scale: 2,
        useCORS: true,
        logging: false,
        backgroundColor: null
      }).then((canvas) => {
        const link = document.createElement("a")
        link.download = filename
        link.href = canvas.toDataURL("image/png")
        link.click()
      })
    })
  }
}

export const Hooks = {
  CopyButton,
  ApiTokensUsageChart,
  CapacityColor,
  BasinChartTimeWindow,
  DamChartTimeWindow,
  DamChartMount,
  DischargeChartMount,
  DamRealtimeChartMount,
  DataPointsChart,
  AdminProductChart,
  ExportDamCard,
  ExportBasinCard,
  RiverChanged,
  UsageTypeChanged,
  SearchDam,
  DamMultiselectSearch,
  DarkModeToggle,
  AvatarMenu,
  NavRouteActive,
  BasinMiniMap,
  StorageReportPortugalMap,
  StorageReportPdfExport,
  OpenSettingsModal,
  SettingsModalBackdrop,
  SettingsModalCloseButton,
  ContactForm,
  OpenContactModal,
  ContactModalBackdrop,
  ContactModalCloseButton,
  OpenInfoModal,
  InfoModalBackdrop,
  InfoModalCloseButton
}
