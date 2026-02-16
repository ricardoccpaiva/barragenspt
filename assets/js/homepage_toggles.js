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

function turnOffAlerts() {
  const toggle = document.getElementById("toggleAlerts")
  if (toggle) toggle.checked = false
}

/** Turn off all overlay layers (PDSI, SMI, Rain, Alertas). Used on navigation to dam or when clearing. */
export function clearOverlayLayers() {
  if (typeof topbar !== "undefined") topbar.hide()
  turnOffPdsi()
  turnOffSmi()
  turnOffRain()
  turnOffAlerts()
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
          const active = el.checked
          if (active) {
            const map = getMap()
            const alertsToggle = document.getElementById("toggleAlerts")
            if (alertsToggle?.checked) {
              turnOffAlerts()
              this.pushEvent("toggle_alerts", { checked: false })
            }
            const pdsiToggle = document.getElementById("togglePdsi")
            if (pdsiToggle?.checked) {
              pdsiToggle.checked = false
              removePdsiLayer(map)
            }
            const smiToggle = document.getElementById("toggleSmi")
            if (smiToggle?.checked) {
              smiToggle.checked = false
              removeSmiLayer(map)
              const smiSliderWrap = document.getElementById("smi-slider-wrap")
              if (smiSliderWrap) smiSliderWrap.classList.add("hidden")
            }
            const rainToggle = document.getElementById("toggleRain")
            if (rainToggle?.checked) {
              rainToggle.checked = false
              removeRainLayer(map)
              const rainSliderWrap = document.getElementById("rain-slider-wrap")
              if (rainSliderWrap) rainSliderWrap.classList.add("hidden")
            }
          }
          applyBasinsLayerActive(active)
          this.pushEvent("toggle_basins", { checked: active })
        })
      }
      applyBasinsLayerActive(el.checked)
    }
  },
  DamsLayerToggle: {
    mounted() {
      const el = this.el
      if (!el._damsListenerAdded) {
        el._damsListenerAdded = true
        el.addEventListener("change", () => applyDamsLayerActive(el.checked))
      }
      applyDamsLayerActive(el.checked)
    }
  },
  SpainLayerToggle: {
    mounted() {
      const el = this.el
      el.addEventListener("change", () => {
        if (el.checked) {
          const alertsToggle = document.getElementById("toggleAlerts")
          if (alertsToggle?.checked) {
            turnOffAlerts()
            this.pushEvent("toggle_alerts", { checked: false })
          }
        }
        this.pushEvent("toggle_spain", { checked: el.checked })
      })
      if (el.checked) this.pushEvent("toggle_spain", { checked: el.checked })
    }
  },
  AlertsToggle: {
    mounted() {
      const el = this.el
      el.addEventListener("change", () => {
        if (el.checked) {
          const basinsToggle = document.getElementById("toggleBasins")
          if (basinsToggle?.checked) {
            basinsToggle.checked = false
            applyBasinsLayerActive(false)
          }
        }
        this.pushEvent("toggle_alerts", { checked: el.checked })
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
        const map = getMap()
        if (!map) return
        if (el.checked) {
          const alertsToggle = document.getElementById("toggleAlerts")
          if (alertsToggle?.checked) {
            turnOffAlerts()
            this.pushEvent("toggle_alerts", { checked: false })
          }
          const basinsToggle = document.getElementById("toggleBasins")
          if (basinsToggle) {
            basinsToggle.checked = false
            applyBasinsLayerActive(false)
          }
          const smiToggle = document.getElementById("toggleSmi")
          if (smiToggle?.checked) {
            smiToggle.checked = false
            removeSmiLayer(map)
            const smiSliderWrap = document.getElementById("smi-slider-wrap")
            if (smiSliderWrap) smiSliderWrap.classList.add("hidden")
          }
          const rainToggle = document.getElementById("toggleRain")
          if (rainToggle?.checked) {
            rainToggle.checked = false
            removeRainLayer(map)
            const rainSliderWrap = document.getElementById("rain-slider-wrap")
            if (rainSliderWrap) rainSliderWrap.classList.add("hidden")
          }
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
      const depthPillsContainer = document.getElementById("smi-depth-pills")

      function getSmiVser() {
        const active = depthPillsContainer?.querySelector(".smi-depth-pill-active")
        const v = active?.getAttribute("data-value")
        return v && ["p7", "p28", "p100"].includes(v) ? v : "p28"
      }

      function setSmiDepthActive(pillEl) {
        depthPillsContainer?.querySelectorAll(".smi-depth-pill").forEach((btn) => {
          btn.classList.remove("smi-depth-pill-active", "bg-brand-500", "text-white", "border-brand-600")
          btn.classList.add("border-slate-200", "bg-slate-50", "text-slate-700")
        })
        if (pillEl) {
          pillEl.classList.add("smi-depth-pill-active", "bg-brand-500", "text-white", "border-brand-600")
          pillEl.classList.remove("border-slate-200", "bg-slate-50", "text-slate-700")
        }
      }

      function pushSmiChangeDate() {
        const sliderVal = daySlider ? parseInt(daySlider.value, 10) : 29
        const daysAgo = 30 - sliderVal
        if (sliderLabel) sliderLabel.textContent = "A carregar..."
        this.pushEvent("smi_change_date", { days_ago: daysAgo, vser: getSmiVser() })
      }

      el.addEventListener("change", () => {
        const map = getMap()
        if (!map) return
        if (el.checked) {
          const alertsToggle = document.getElementById("toggleAlerts")
          if (alertsToggle?.checked) {
            turnOffAlerts()
            this.pushEvent("toggle_alerts", { checked: false })
          }
          const basinsToggle = document.getElementById("toggleBasins")
          if (basinsToggle) {
            basinsToggle.checked = false
            applyBasinsLayerActive(false)
          }
          const pdsiToggle = document.getElementById("togglePdsi")
          if (pdsiToggle?.checked) {
            pdsiToggle.checked = false
            removePdsiLayer(map)
            const pdsiSliderWrap = document.getElementById("pdsi-slider-wrap")
            if (pdsiSliderWrap) pdsiSliderWrap.classList.add("hidden")
          }
          const rainToggle = document.getElementById("toggleRain")
          if (rainToggle?.checked) {
            rainToggle.checked = false
            removeRainLayer(map)
            const rainSliderWrap = document.getElementById("rain-slider-wrap")
            if (rainSliderWrap) rainSliderWrap.classList.add("hidden")
          }
          if (sliderWrap) {
            sliderWrap.classList.remove("hidden")
            if (daySlider) daySlider.value = "29"
            if (sliderLabel) sliderLabel.textContent = "A carregar..."
          }
          el.disabled = true
          topbar.show()
          this.pushEvent("toggle_smi", { checked: true, vser: getSmiVser() })
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

      depthPillsContainer?.querySelectorAll(".smi-depth-pill").forEach((btn) => {
        btn.addEventListener("click", () => {
          setSmiDepthActive(btn)
          if (!el.checked) return
          if (sliderLabel) sliderLabel.textContent = "A carregar..."
          pushSmiChangeDate.call(this)
        })
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

      function pushRainChangeDate() {
        const sliderVal = rainDaySlider ? parseInt(rainDaySlider.value, 10) : 15
        const dayOffset = sliderVal - 15
        if (rainSliderLabel) rainSliderLabel.textContent = "A carregar..."
        this.pushEvent("rain_change_date", { day_offset: dayOffset })
      }

      el.addEventListener("change", () => {
        const map = getMap()
        if (!map) return
        if (el.checked) {
          const alertsToggle = document.getElementById("toggleAlerts")
          if (alertsToggle?.checked) {
            turnOffAlerts()
            this.pushEvent("toggle_alerts", { checked: false })
          }
          const basinsToggle = document.getElementById("toggleBasins")
          if (basinsToggle) {
            basinsToggle.checked = false
            applyBasinsLayerActive(false)
          }
          const pdsiToggle = document.getElementById("togglePdsi")
          if (pdsiToggle?.checked) {
            pdsiToggle.checked = false
            removePdsiLayer(map)
            const pdsiSliderWrap = document.getElementById("pdsi-slider-wrap")
            if (pdsiSliderWrap) pdsiSliderWrap.classList.add("hidden")
          }
          const smiToggle = document.getElementById("toggleSmi")
          if (smiToggle?.checked) {
            smiToggle.checked = false
            removeSmiLayer(map)
            const smiSliderWrap = document.getElementById("smi-slider-wrap")
            if (smiSliderWrap) smiSliderWrap.classList.add("hidden")
          }
          if (rainWrap) {
            rainWrap.classList.remove("hidden")
            if (rainDaySlider) rainDaySlider.value = "15"
            if (rainSliderLabel) rainSliderLabel.textContent = "A carregar..."
          }
          el.disabled = true
          topbar.show()
          this.pushEvent("toggle_rain", { checked: true })
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
    map.fitBounds([[-9.708570, 36.682035], [-6.072327, 42.615949]])
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
    if (map && e.detail) drawSmiLayer(map, cleaned, e.detail.date)
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
      smiToggle.checked = false
      smiToggle.disabled = false
    }
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
    if (map && e.detail) drawRainLayer(map, cleaned, e.detail.date)
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
