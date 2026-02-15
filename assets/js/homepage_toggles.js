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
import { findAvailableDate as findSmiAvailableDate, addSmiLayer, removeSmiLayer } from "./homepage/smi_layer"

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
            const pdsiToggle = document.getElementById("togglePdsi")
            if (pdsiToggle?.checked) {
              pdsiToggle.checked = false
              removePdsiLayer(map)
            }
            const smiToggle = document.getElementById("toggleSmi")
            if (smiToggle?.checked) {
              smiToggle.checked = false
              removeSmiLayer(map)
            }
          }
          applyBasinsLayerActive(active)
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
      el.addEventListener("change", () => this.pushEvent("toggle_spain", { checked: el.checked }))
      if (el.checked) this.pushEvent("toggle_spain", { checked: el.checked })
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
          const basinsToggle = document.getElementById("toggleBasins")
          if (basinsToggle) {
            basinsToggle.checked = false
            applyBasinsLayerActive(false)
          }
          const smiToggle = document.getElementById("toggleSmi")
          if (smiToggle?.checked) {
            smiToggle.checked = false
            removeSmiLayer(map)
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
          removePdsiLayer(map)
          if (sliderWrap) sliderWrap.classList.add("hidden")
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
      el.addEventListener("change", () => {
        const map = getMap()
        if (!map) return
        if (el.checked) {
          const basinsToggle = document.getElementById("toggleBasins")
          if (basinsToggle) {
            basinsToggle.checked = false
            applyBasinsLayerActive(false)
          }
          const pdsiToggle = document.getElementById("togglePdsi")
          if (pdsiToggle?.checked) {
            pdsiToggle.checked = false
            removePdsiLayer(map)
          }
          el.disabled = true
          topbar.show()
          findSmiAvailableDate()
            .then((isoDateStr) => {
              addSmiLayer(map, isoDateStr)
              el.disabled = false
              topbar.hide()
            })
            .catch(() => {
              el.checked = false
              el.disabled = false
              topbar.hide()
            })
        } else {
          removeSmiLayer(map)
        }
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
}

registerSpainListeners()
