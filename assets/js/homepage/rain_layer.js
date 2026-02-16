/**
 * Chuva (precipitation) layer: reacts to draw_rain_layer / remove_rain_layer.
 * Same GeoJSON by zid as SMI; fill color by precipitation value.
 */

const GEOJSON_URL = "/geojson/pt100_conc.json"
const RAIN_SOURCE_ID = "rain-geojson"
const RAIN_FILL_LAYER_ID = "rain-fill"
const RAIN_OUTLINE_LAYER_ID = "rain-outline"

const RAIN_NO_DATA_COLOR = "#94a3b8"
const RAIN_VALUES = [0.1, 2, 5, 10, 20, 30, 35, 40, 50, 60, 90, 120]
const RAIN_COLORS = [
  "#ffffff",
  "#afd7ff",
  "#99ccff",
  "#77aaff",
  "#0077ff",
  "#0066dd",
  "#ffee00",
  "#ffdd00",
  "#ffaa00",
  "#ff7700",
  "#ff0000",
  "#ff00bb",
  "#dddddd"
]

function rainFillColorExpression() {
  const step = ["step", ["get", "prec"], RAIN_COLORS[0]]
  RAIN_VALUES.forEach((threshold, i) => {
    if (i + 1 < RAIN_COLORS.length) step.push(threshold, RAIN_COLORS[i + 1])
  })
  return step
}

function formatRainDateLabel(isoDateStr) {
  if (!isoDateStr) return ""
  const [y, m, d] = isoDateStr.split("-").map(Number)
  if (!y || !m || !d) return isoDateStr
  const months = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"]
  return `Dados de ${d} ${months[m - 1]} ${y}`
}

function showRainLegend(isoDateStr) {
  const dateEl = document.getElementById("legend-rain-date")
  const rainEl = document.getElementById("legend-rain")
  const storageEl = document.getElementById("legend-storage")
  const pdsiEl = document.getElementById("legend-pdsi")
  const smiEl = document.getElementById("legend-smi")
  if (dateEl) dateEl.textContent = formatRainDateLabel(isoDateStr)
  if (rainEl) rainEl.classList.remove("hidden")
  if (storageEl) storageEl.classList.add("hidden")
  if (pdsiEl) pdsiEl.classList.add("hidden")
  if (smiEl) smiEl.classList.add("hidden")
}

function hideRainLegend() {
  const rainEl = document.getElementById("legend-rain")
  const storageEl = document.getElementById("legend-storage")
  const pdsiEl = document.getElementById("legend-pdsi")
  const smiEl = document.getElementById("legend-smi")
  if (rainEl) rainEl.classList.add("hidden")
  if (storageEl && (!pdsiEl || pdsiEl.classList.contains("hidden")) && (!smiEl || smiEl.classList.contains("hidden"))) storageEl.classList.remove("hidden")
}

function normalizeValuesByZid(data) {
  if (!data || typeof data !== "object") return {}
  if (Array.isArray(data)) {
    const out = {}
    data.forEach((item) => {
      const zid = item?.zid ?? item?.zoneid ?? item?.id
      const v = item?.value ?? item?.val ?? item?.prec ?? item?.precipitation
      if (zid == null || typeof v !== "number" || Number.isNaN(v)) return
      const key = String(zid)
      out[key] = v
      if (key.startsWith("concelhos_")) out[key.replace(/^concelhos_/, "")] = v
    })
    return out
  }
  if (data.data && typeof data.data === "object") return normalizeValuesByZid(data.data)
  const out = {}
  Object.entries(data).forEach(([k, v]) => {
    if (typeof v !== "number" || Number.isNaN(v)) return
    const key = String(k).trim()
    out[key] = v
    if (key.startsWith("concelhos_")) out[key.replace(/^concelhos_/, "")] = v
  })
  return out
}

function mergeRainIntoFeatures(geojson, valuesByZid) {
  const features = (geojson.features || []).map((f) => {
    const props = f.properties || {}
    const zid = props.zid != null ? String(props.zid) : (props.zoneid || "").replace(/^concelhos_/, "")
    const prec = zid ? (valuesByZid[zid] ?? valuesByZid["concelhos_" + zid]) : null
    const num = prec != null && typeof prec === "number" && !Number.isNaN(prec) ? prec : null
    return { ...f, properties: { ...props, prec: num } }
  })
  return { type: "FeatureCollection", features }
}

function removeRainLayersAndSource(map) {
  if (map.getLayer(RAIN_OUTLINE_LAYER_ID)) map.removeLayer(RAIN_OUTLINE_LAYER_ID)
  if (map.getLayer(RAIN_FILL_LAYER_ID)) map.removeLayer(RAIN_FILL_LAYER_ID)
  if (map.getSource(RAIN_SOURCE_ID)) map.removeSource(RAIN_SOURCE_ID)
}

export function drawRainLayer(map, rawValues, dateStr) {
  if (!map) return
  const valuesByZid = normalizeValuesByZid(rawValues)
  fetch(GEOJSON_URL)
    .then((r) => r.json())
    .then((geojson) => {
      const merged = mergeRainIntoFeatures(geojson, valuesByZid)
      removeRainLayersAndSource(map)
      map.addSource(RAIN_SOURCE_ID, { type: "geojson", data: merged })
      map.addLayer({
        id: RAIN_FILL_LAYER_ID,
        type: "fill",
        source: RAIN_SOURCE_ID,
        paint: { "fill-color": rainFillColorExpression(), "fill-opacity": 1 }
      })
      map.addLayer({
        id: RAIN_OUTLINE_LAYER_ID,
        type: "line",
        source: RAIN_SOURCE_ID,
        paint: { "line-color": "#333", "line-width": 0.5 }
      })
      showRainLegend(dateStr || null)
    })
}

export function removeRainLayer(map) {
  if (!map) return
  removeRainLayersAndSource(map)
  hideRainLegend()
}
