import topbar from "../vendor/topbar"
import { getStorageColor, DAMS_CIRCLE_COLOR_GRAY } from "./utils/colors"

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
      this.pushEvent("update_selected_usage_types", { usage_type: usageType, checked })
    })
  }
}

const SearchDam = {
  mounted() {
    this.el.addEventListener("input", () => this.pushEvent("search_dam", { search_term: this.el.value }))
  }
}

const DarkModeToggle = {
  mounted() {
    const el = this.el
    el.checked = document.documentElement.classList.contains("dark")
    el.addEventListener("change", () => {
      const on = el.checked
      document.documentElement.classList.toggle("dark", on)
      try { localStorage.setItem("darkMode", on ? "1" : "0") } catch (e) {}
      window.dispatchEvent(new CustomEvent("dark-mode-change", { detail: { dark: on } }))
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

export const Hooks = {
  CapacityColor,
  BasinChartTimeWindow,
  DamChartTimeWindow,
  DamChartMount,
  DischargeChartMount,
  DamRealtimeChartMount,
  RiverChanged,
  UsageTypeChanged,
  SearchDam,
  DarkModeToggle,
  SettingsModalBackdrop,
  SettingsModalCloseButton
}
