import topbar from "../vendor/topbar"
import { DAMS_CIRCLE_COLOR_GRAY, capacityColorStepExpression } from "./utils/colors"
import {
  findAvailableDate,
  addPdsiLayer,
  removePdsiLayer,
  getPdsiDateForMonthOffset,
  getPdsiMonthOffsetFromDate,
  getPdsiMonthLabelForOffset
} from "./homepage/pdsi_layer"
import { drawSmiLayer, removeSmiLayer } from "./homepage/smi_layer"
import { drawRainLayer, removeRainLayer } from "./homepage/rain_layer"

function getMap() {
  return window.map
}

function gtagEvent(name, params) {
  if (typeof gtag === "function") gtag("event", name, params)
}

export function applyBasinsLayerActive(active) {
  const map = getMap()
  if (!map) return
  const style = map.getStyle()
  if (!style || !style.layers) return
  const opacity = active ? 0.7 : 0.1
  style.layers.forEach((layer) => {
    if (layer.type === "fill" && layer.id.endsWith("_fill")) {
      map.setPaintProperty(layer.id, "fill-opacity", opacity)
    }
  })
}

export function applyDamsLayerActive(active) {
  const map = getMap()
  if (!map || !map.getLayer("dams-circles")) return
  map.setPaintProperty("dams-circles", "circle-color", active ? capacityColorStepExpression("pct") : DAMS_CIRCLE_COLOR_GRAY)
}

/** Single place for "off" behaviour: uncheck toggle, remove layer, hide slider. Always removes layer from map (e.g. after LiveView re-render toggles may already be unchecked). */
function turnOffPdsi() {
  const toggle = document.getElementById("togglePdsi")
  if (toggle) toggle.checked = false
  const map = getMap()
  if (map) removePdsiLayer(map)
  const wrap = document.getElementById("pdsi-slider-wrap")
  if (wrap) wrap.classList.add("hidden")
}

function turnOffSmi() {
  const toggle = document.getElementById("toggleSmi")
  if (toggle) toggle.checked = false
  const map = getMap()
  if (map) removeSmiLayer(map)
  const wrap = document.getElementById("smi-slider-wrap")
  if (wrap) wrap.classList.add("hidden")
}

function turnOffRain() {
  const toggle = document.getElementById("toggleRain")
  if (toggle) toggle.checked = false
  const map = getMap()
  if (map) removeRainLayer(map)
  const wrap = document.getElementById("rain-slider-wrap")
  if (wrap) wrap.classList.add("hidden")
}

/** When activating toggle X, turn off these (client-only). */
const TOGGLE_DEPS = {
  basins: ["alerts", "pdsi", "smi", "rain"],
  spain: ["alerts"],
  alerts: ["basins", "spain", "pdsi", "smi", "rain"],
  pdsi: ["alerts", "basins", "smi", "rain"],
  smi: ["alerts", "basins", "pdsi", "rain"],
  rain: ["alerts", "basins", "pdsi", "smi"]
}

const TURN_OFF_FNS = {
  alerts: () => turnOffAlerts(),
  basins: () => turnOffBasins(),
  pdsi: () => turnOffPdsi(),
  smi: () => turnOffSmi(),
  rain: () => turnOffRain(),
  spain: () => turnOffSpain()
}

function whenTurningOn(toggleId) {
  const deps = TOGGLE_DEPS[toggleId]
  if (!deps) return
  deps.forEach((dep) => {
    const fn = TURN_OFF_FNS[dep]
    if (fn) fn()
  })
}

function turnOffBasins() {
  const toggle = document.getElementById("toggleBasins")
  if (toggle) toggle.checked = false
  applyBasinsLayerActive(false)
}

function turnOnBasins() {
  applyBasinsLayerActive(true)
}

function turnOffDams() {
  const toggle = document.getElementById("toggleDams")
  if (toggle) toggle.checked = false
  applyDamsLayerActive(false)
}

function turnOnDams() {
  applyDamsLayerActive(true)
}

/** Remove Spain basin layers from map (same logic as phx:remove_spain_basins). */
function removeSpainBasinsFromMap() {
  if (typeof topbar !== "undefined") topbar.hide()
  window.spainBasins = []
  const map = getMap()
  if (!map) return
  const style = map.getStyle()
  if (!style || !style.layers) return
  const sourceIds = {}
  style.layers.forEach((layer) => {
    if (layer.id.startsWith("es_")) {
      if (map.getLayer(layer.id)) map.removeLayer(layer.id)
      const sourceId = layer.id.replace(/_fill$/, "").replace(/_outline$/, "")
      if (layer.id !== sourceId) sourceIds[sourceId] = true
    }
  })
  Object.keys(sourceIds).forEach((sid) => {
    if (map.getSource(sid)) map.removeSource(sid)
  })
  map.fitBounds([
    [-17.30384751295111, 36.50952345455322],
    [-2.262873003102527, 42.457622802586286]
  ])
}

function turnOffSpain() {
  const toggle = document.getElementById("toggleSpain")
  if (toggle) toggle.checked = false
  removeSpainBasinsFromMap()
}

function applyCachedBasinsSummary() {
  const basinsSummary = window.cachedBasinsSummary
  if (!basinsSummary || !basinsSummary.length) return
  const map = getMap()
  if (!map) return
  const style = map.getStyle()
  if (!style || !style.layers) return
  const basinsVisible = document.getElementById("toggleBasins")?.checked ?? true
  const opacity = basinsVisible ? 0.7 : 0
  style.layers.forEach((item) => {
    if (!item.id.includes("_fill")) return
    const summaryForBasin = basinsSummary.find((b) => b.id + "_fill" === item.id)
    if (summaryForBasin != null) {
      map.setPaintProperty(item.id, "fill-color", summaryForBasin.capacity_color)
      map.setPaintProperty(item.id, "fill-opacity", opacity)
    } else {
      map.setPaintProperty(item.id, "fill-opacity", 0)
    }
  })
  const legendStorage = document.getElementById("legend-storage")
  const legendAlerts = document.getElementById("legend-alerts")
  if (legendAlerts) legendAlerts.classList.add("hidden")
  if (legendStorage) legendStorage.classList.remove("hidden")
}

function turnOffAlerts() {
  const toggle = document.getElementById("toggleAlerts")
  if (toggle) toggle.checked = false
  applyCachedBasinsSummary()
}

/** Turn off all overlay layers (PDSI, SMI, Rain, Alertas, Spain). Used on navigation to dam or when clearing. */
export function clearOverlayLayers() {
  if (typeof topbar !== "undefined") topbar.hide()
  turnOffPdsi()
  turnOffSmi()
  turnOffRain()
  turnOffAlerts()
  turnOffSpain()
}

export const DAMS_CIRCLE_COLOR_GRAY_EXPORT = DAMS_CIRCLE_COLOR_GRAY

export function navigateToSpainBasin(basinId) {
  const link = document.getElementById("basinDetailLink")
  const target = `/basins/${basinId}?country=es`
  if (link) {
    link.setAttribute("href", target)
    link.click()
    return
  }
  window.location.href = target
}

export const LayerToggleHooks = {
  BasinsLayerToggle: {
    mounted() {
      const el = this.el
      if (!el._basinsListenerAdded) {
        el._basinsListenerAdded = true
        el.addEventListener("change", () => {
          gtagEvent("toggle_layer", { layer: "basins", state: el.checked ? "on" : "off" })
          if (el.checked) {
            whenTurningOn("basins")
            turnOnBasins()
          } else {
            turnOffBasins()
          }
        })
      }
      //applyBasinsLayerActive(el.checked)
    }
  },
  DamsLayerToggle: {
    mounted() {
      const el = this.el
      if (!el._damsListenerAdded) {
        el._damsListenerAdded = true
        el.addEventListener("change", () => {
          gtagEvent("toggle_layer", { layer: "dams", state: el.checked ? "on" : "off" })
          if (el.checked) turnOnDams()
          else turnOffDams()
        })
      }
      //applyDamsLayerActive(el.checked)
    }
  },
  SpainLayerToggle: {
    mounted() {
      const el = this.el
      el.addEventListener("change", () => {
        gtagEvent("toggle_layer", { layer: "spain", state: el.checked ? "on" : "off" })
        if (el.checked) {
          whenTurningOn("spain")
          this.pushEvent("toggle_spain", { checked: true })
        } else {
          turnOffSpain()
        }
      })
      if (el.checked) this.pushEvent("toggle_spain", { checked: true })
    }
  },
  AlertsToggle: {
    mounted() {
      const el = this.el
      el.addEventListener("change", () => {
        gtagEvent("toggle_layer", { layer: "alerts", state: el.checked ? "on" : "off" })
        if (el.checked) {
          whenTurningOn("alerts")
          this.pushEvent("toggle_alerts", { checked: true })
        } else {
          turnOffAlerts()
        }
      })
    }
  },
  PdsiLayerToggle: {
    mounted() {
      const el = this.el
      if (el._pdsiListenerAdded) return
      el._pdsiListenerAdded = true
      const sliderWrap = document.getElementById("pdsi-slider-wrap")
      const monthSlider = document.getElementById("pdsi-month-slider")
      const sliderLabel = document.getElementById("pdsi-slider-label")

      function updatePdsiSliderFromDate(fmtDateStr) {
        if (!monthSlider || !sliderLabel) return
        const monthsAgo = getPdsiMonthOffsetFromDate(fmtDateStr)
        monthSlider.value = String(12 - monthsAgo)
        sliderLabel.textContent = getPdsiMonthLabelForOffset(monthsAgo)
      }

      function onPdsiSliderInput() {
        const map = getMap()
        if (!map || !monthSlider) return
        const monthsAgo = 12 - parseInt(monthSlider.value, 10)
        const dateStr = getPdsiDateForMonthOffset(monthsAgo)
        addPdsiLayer(map, dateStr)
        if (sliderLabel) sliderLabel.textContent = getPdsiMonthLabelForOffset(monthsAgo)
      }

      el.addEventListener("change", () => {
        gtagEvent("toggle_layer", { layer: "pdsi", state: el.checked ? "on" : "off" })
        const map = getMap()
        if (!map) return
        if (el.checked) {
          whenTurningOn("pdsi")
          el.disabled = true
          topbar.show()
          findAvailableDate()
            .then((fmtDateStr) => {
              addPdsiLayer(map, fmtDateStr)
              if (sliderWrap) sliderWrap.classList.remove("hidden")
              updatePdsiSliderFromDate(fmtDateStr)
              el.disabled = false
              topbar.hide()
            })
            .catch(() => {
              el.checked = false
              el.disabled = false
              topbar.hide()
            })
        } else {
          turnOffPdsi()
        }
      })

      if (monthSlider) {
        monthSlider.addEventListener("input", onPdsiSliderInput)
      }
    }
  },
  SmiLayerToggle: {
    mounted() {
      const el = this.el
      if (el._smiListenerAdded) return
      el._smiListenerAdded = true
      const sliderWrap = document.getElementById("smi-slider-wrap")
      const daySlider = document.getElementById("smi-day-slider")
      const sliderLabel = document.getElementById("smi-slider-label")
      const depthSelect = document.getElementById("smi-depth-select")
      const vlevSelect = document.getElementById("smi-vlev-select")

      function getSmiVser() {
        const v = depthSelect?.value
        return v && ["p7", "p28", "p100"].includes(v) ? v : "p28"
      }

      function getSmiVlev() {
        const v = vlevSelect?.value
        return v && ["conc", "nuts3", "dist", "nuts2", "hidro"].includes(v) ? v : "conc"
      }

      function pushSmiChangeDate() {
        const sliderVal = daySlider ? parseInt(daySlider.value, 10) : 29
        const daysAgo = 30 - sliderVal
        if (sliderLabel) sliderLabel.textContent = "A carregar..."
        this.pushEvent("smi_change_date", { days_ago: daysAgo, vser: getSmiVser(), vlev: getSmiVlev() })
      }

      el.addEventListener("change", () => {
        gtagEvent("toggle_layer", { layer: "smi", state: el.checked ? "on" : "off" })
        const map = getMap()
        if (!map) return
        if (el.checked) {
          whenTurningOn("smi")
          if (sliderWrap) {
            sliderWrap.classList.remove("hidden")
            if (daySlider) daySlider.value = "29"
            if (sliderLabel) sliderLabel.textContent = "A carregar..."
          }
          el.disabled = true
          topbar.show()
          this.pushEvent("toggle_smi", { checked: true, vser: getSmiVser(), vlev: getSmiVlev() })
        } else {
          turnOffSmi()
        }
      })

      if (daySlider) {
        let smiSliderDebounce = null
        const SMI_SLIDER_DEBOUNCE_MS = 350
        daySlider.addEventListener("input", () => {
          if (!el.checked) return
          if (smiSliderDebounce) clearTimeout(smiSliderDebounce)
          smiSliderDebounce = setTimeout(() => {
            smiSliderDebounce = null
            pushSmiChangeDate.call(this)
          }, SMI_SLIDER_DEBOUNCE_MS)
        })
      }

      depthSelect?.addEventListener("change", () => {
        gtagEvent("smi_depth_change", { value: depthSelect.value })
        if (!el.checked) return
        if (sliderLabel) sliderLabel.textContent = "A carregar..."
        pushSmiChangeDate.call(this)
      })

      vlevSelect?.addEventListener("change", () => {
        gtagEvent("smi_aggregation_change", { value: vlevSelect.value })
        if (!el.checked) return
        if (sliderLabel) sliderLabel.textContent = "A carregar..."
        pushSmiChangeDate.call(this)
      })
    }
  },
  RainLayerToggle: {
    mounted() {
      const el = this.el
      if (el._rainListenerAdded) return
      el._rainListenerAdded = true
      const rainWrap = document.getElementById("rain-slider-wrap")
      const rainDaySlider = document.getElementById("rain-day-slider")
      const rainSliderLabel = document.getElementById("rain-slider-label")
      const rainVlevSelect = document.getElementById("rain-vlev-select")

      function getRainVlev() {
        const v = rainVlevSelect?.value
        return v && ["conc", "nuts3", "dist", "nuts2", "hidro"].includes(v) ? v : "conc"
      }

      function pushRainChangeDate() {
        const sliderVal = rainDaySlider ? parseInt(rainDaySlider.value, 10) : 15
        const dayOffset = sliderVal - 15
        if (rainSliderLabel) rainSliderLabel.textContent = "A carregar..."
        this.pushEvent("rain_change_date", { day_offset: dayOffset, vlev: getRainVlev() })
      }

      el.addEventListener("change", () => {
        gtagEvent("toggle_layer", { layer: "rain", state: el.checked ? "on" : "off" })
        const map = getMap()
        if (!map) return
        if (el.checked) {
          whenTurningOn("rain")
          if (rainWrap) {
            rainWrap.classList.remove("hidden")
            if (rainDaySlider) rainDaySlider.value = "15"
            if (rainSliderLabel) rainSliderLabel.textContent = "A carregar..."
          }
          el.disabled = true
          topbar.show()
          this.pushEvent("toggle_rain", { checked: true, vlev: getRainVlev() })
        } else {
          turnOffRain()
        }
      })

      if (rainDaySlider) {
        let rainSliderDebounce = null
        const RAIN_SLIDER_DEBOUNCE_MS = 350
        rainDaySlider.addEventListener("input", () => {
          if (!el.checked) return
          if (rainSliderDebounce) clearTimeout(rainSliderDebounce)
          rainSliderDebounce = setTimeout(() => {
            rainSliderDebounce = null
            pushRainChangeDate.call(this)
          }, RAIN_SLIDER_DEBOUNCE_MS)
        })
      }

      rainVlevSelect?.addEventListener("change", () => {
        gtagEvent("rain_aggregation_change", { value: rainVlevSelect.value })
        if (!el.checked) return
        if (rainSliderLabel) rainSliderLabel.textContent = "A carregar..."
        pushRainChangeDate.call(this)
      })
    }
  }
}

window.spainBasins = []

function registerSpainListeners() {
  window.addEventListener("phx:draw_spain_basins", (e) => {
    if (typeof topbar !== "undefined") topbar.hide()
    const map = getMap()
    if (!map) return
    const basins = e.detail.basins || []
    window.spainBasins = basins
    basins.forEach((item) => {
      const sourceId = "es_" + item.basin_name
      const fillLayerId = sourceId + "_fill"
      const outlineLayerId = sourceId + "_outline"
      if (map.getSource(sourceId)) return
      map.addSource(sourceId, { type: "geojson", data: "/geojson/spain/" + item.basin_name + ".geojson" })
      map.addLayer({
        id: fillLayerId,
        type: "fill",
        source: sourceId,
        layout: {},
        paint: { "fill-color": item.capacity_color || "#94a3b8", "fill-opacity": 0.6 }
      })
      map.addLayer({
        id: outlineLayerId,
        type: "line",
        source: sourceId,
        layout: {},
        paint: { "line-color": "#000", "line-width": 0.5 }
      })
      map.on("click", fillLayerId, (ev) => {
        const sid = ev.features[0].source
        const basinName = sid.replace(/^es_/, "")
        const basin = window.spainBasins.find((b) => b.basin_name === basinName)
        if (basin) navigateToSpainBasin(basin.id)
      })
      map.on("mouseenter", fillLayerId, () => { map.getCanvas().style.cursor = "pointer" })
      map.on("mouseleave", fillLayerId, () => { map.getCanvas().style.cursor = "" })
    })
    map.fitBounds([[-10.0186, 35.588], [3.8135, 43.9644]])
  })

  window.addEventListener("phx:remove_spain_basins", () => {
    removeSpainBasinsFromMap()
  })

  window.addEventListener("phx:draw_smi_layer", (e) => {
    if (typeof topbar !== "undefined") topbar.hide()
    const map = getMap()
    const smiToggle = document.getElementById("toggleSmi")
    if (smiToggle) smiToggle.disabled = false
    const cleaned = Object.fromEntries(
      Object.entries(e.detail.values).map(([key, value]) => [
        key.replace(/^a_/, ""),
        value
      ])
    )
    if (map && e.detail) drawSmiLayer(map, cleaned, e.detail.date, e.detail.vlev)
    const smiSliderLabel = document.getElementById("smi-slider-label")
    if (e.detail.date && smiSliderLabel) {
      const dateStr = e.detail.date.slice(0, 10)
      const [y, m, d] = dateStr.split("-").map(Number)
      if (y && m && d) {
        const months = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"]
        smiSliderLabel.textContent = `${d} ${months[m - 1]} ${y}`
      }
    }
  })

  window.addEventListener("phx:clear_overlay_layers", () => {
    clearOverlayLayers()
  })

  window.addEventListener("phx:smi_layer_error", () => {
    if (typeof topbar !== "undefined") topbar.hide()
    const smiToggle = document.getElementById("toggleSmi")
    if (smiToggle) {
      smiToggle.disabled = false
    }
    const map = getMap()
    if (map) removeSmiLayer(map)
    const smiSliderLabel = document.getElementById("smi-slider-label")
    if (smiSliderLabel) smiSliderLabel.textContent = "Sem dados para esta data"
  })

  window.addEventListener("phx:draw_rain_layer", (e) => {
    if (typeof topbar !== "undefined") topbar.hide()
    const map = getMap()
    const rainToggle = document.getElementById("toggleRain")
    if (rainToggle) rainToggle.disabled = false
    const cleaned = Object.fromEntries(
      Object.entries(e.detail.values || {}).map(([key, value]) => [
        key.replace(/^a_/, ""),
        value
      ])
    )
    if (map && e.detail) drawRainLayer(map, cleaned, e.detail.date, e.detail.vlev)
    const rainSliderLabel = document.getElementById("rain-slider-label")
    if (e.detail.date && rainSliderLabel) {
      const dateStr = e.detail.date.slice(0, 10)
      const [y, m, d] = dateStr.split("-").map(Number)
      if (y && m && d) {
        const months = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"]
        rainSliderLabel.textContent = `${d} ${months[m - 1]} ${y}`
      }
    }
  })

  window.addEventListener("phx:rain_layer_error", () => {
    if (typeof topbar !== "undefined") topbar.hide()
    const rainToggle = document.getElementById("toggleRain")
    if (rainToggle) rainToggle.disabled = false
    const rainSliderLabel = document.getElementById("rain-slider-label")
    if (rainSliderLabel) rainSliderLabel.textContent = "Erro ao carregar"
  })
}

registerSpainListeners()
