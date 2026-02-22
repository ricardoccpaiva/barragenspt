/**
 * SMI layer: reage a push_event do servidor (draw_smi_layer / remove_smi_layer).
 * draw_smi_layer envia { values, date }; este módulo faz fetch do GeoJSON, merge por zid, e pinta o mapa.
 */

const GEOJSON_BY_VLEV = {
  conc: "/geojson/pt100_conc.json",
  nuts3: "/geojson/pt100_nuts3.json",
  dist: "/geojson/pt100_dist.json",
  nuts2: "/geojson/pt100_nuts2.json",
  hidro: "/geojson/pt100_hidro.json"
}
const SMI_SOURCE_ID = "smi-geojson"
const SMI_FILL_LAYER_ID = "smi-fill"
const SMI_OUTLINE_LAYER_ID = "smi-outline"

const MONTH_NAMES_PT = [
  "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
  "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"
]

const SMI_NO_DATA_COLOR = "#94a3b8"
const SMI_VALUES = [-10, 0, 1, 10.01, 20.01, 40.01, 60.01, 80.01, 99.01, 100.01, 130.01, 160.01, 190.01, 200]
const SMI_COLORS = [
  "#ff7e1c", "#ffb408", "#fcdf0d", "#f7ff00", "#cefc00", "#65fa0f", "#44c902",
  "#23a10a", "#066608", "#33ddbb", "#33aaaa", "#3377aa", "#0000ff"
]

function smiFillColorExpression() {
  const step = ["step", ["get", "smi"], SMI_NO_DATA_COLOR]
  SMI_VALUES.forEach((threshold, i) => {
    if (i < SMI_COLORS.length) step.push(threshold, SMI_COLORS[i])
  })
  return step
}

function formatSmiDateLabel(isoDateStr) {
  if (!isoDateStr) return ""
  const [y, m, d] = isoDateStr.split("-").map(Number)
  if (!y || !m || !d) return isoDateStr
  const monthName = MONTH_NAMES_PT[m - 1] || m
  return `Dados de ${d} ${monthName} de ${y}`
}

function showSmiLegend(isoDateStr) {
  const dateEl = document.getElementById("legend-smi-date")
  const smiEl = document.getElementById("legend-smi")
  const storageEl = document.getElementById("legend-storage")
  const pdsiEl = document.getElementById("legend-pdsi")
  const rainEl = document.getElementById("legend-rain")
  if (dateEl) dateEl.textContent = formatSmiDateLabel(isoDateStr)
  if (smiEl) smiEl.classList.remove("hidden")
  if (storageEl) storageEl.classList.add("hidden")
  if (pdsiEl) pdsiEl.classList.add("hidden")
  if (rainEl) rainEl.classList.add("hidden")
}

function hideSmiLegend() {
  const smiEl = document.getElementById("legend-smi")
  const storageEl = document.getElementById("legend-storage")
  const pdsiEl = document.getElementById("legend-pdsi")
  const rainEl = document.getElementById("legend-rain")
  if (smiEl) smiEl.classList.add("hidden")
  if (storageEl && (!pdsiEl || pdsiEl.classList.contains("hidden")) && (!rainEl || rainEl.classList.contains("hidden"))) storageEl.classList.remove("hidden")
}

function normalizeValuesByZid(data) {
  if (!data || typeof data !== "object") return {}
  if (Array.isArray(data)) {
    const out = {}
    data.forEach((item) => {
      const zid = item?.zid ?? item?.zoneid ?? item?.id
      const v = item?.value ?? item?.val ?? item?.smi
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

function mergeSmiIntoFeatures(geojson, valuesByZid) {
  const features = (geojson.features || []).map((f) => {
    const props = f.properties || {}
    const zid = props.zid != null ? String(props.zid) : (props.zoneid || "").replace(/^concelhos_/, "")
    const smi = zid ? (valuesByZid[zid] ?? valuesByZid["concelhos_" + zid]) : null
    const num = smi != null && typeof smi === "number" && !Number.isNaN(smi) ? smi : null
    return { ...f, properties: { ...props, smi: num } }
  })
  return { type: "FeatureCollection", features }
}

function removeSmiLayersAndSource(map) {
  if (map.getLayer(SMI_OUTLINE_LAYER_ID)) map.removeLayer(SMI_OUTLINE_LAYER_ID)
  if (map.getLayer(SMI_FILL_LAYER_ID)) map.removeLayer(SMI_FILL_LAYER_ID)
  if (map.getSource(SMI_SOURCE_ID)) map.removeSource(SMI_SOURCE_ID)
}

/**
 * Chamado pelo listener phx:draw_smi_layer. values = payload do evomaptimeval, date = "YYYY-MM-DD", vlev = nível de agregação.
 */
export function drawSmiLayer(map, rawValues, dateStr, vlev) {
  if (!map) return
  const valuesByZid = normalizeValuesByZid(rawValues)
  const geojsonUrl = (vlev && GEOJSON_BY_VLEV[vlev]) ? GEOJSON_BY_VLEV[vlev] : GEOJSON_BY_VLEV.conc
  fetch(geojsonUrl)
    .then((r) => r.json())
    .then((geojson) => {
      const merged = mergeSmiIntoFeatures(geojson, valuesByZid)
      removeSmiLayersAndSource(map)
      map.addSource(SMI_SOURCE_ID, { type: "geojson", data: merged })
      map.addLayer({
        id: SMI_FILL_LAYER_ID,
        type: "fill",
        source: SMI_SOURCE_ID,
        paint: { "fill-color": smiFillColorExpression(), "fill-opacity": 1 }
      })
      map.addLayer({
        id: SMI_OUTLINE_LAYER_ID,
        type: "line",
        source: SMI_SOURCE_ID,
        paint: { "line-color": "#333", "line-width": 0.5 }
      })
      showSmiLegend(dateStr || null)
    })
}

export function removeSmiLayer(map) {
  if (!map) return
  removeSmiLayersAndSource(map)
  hideSmiLegend()
}
