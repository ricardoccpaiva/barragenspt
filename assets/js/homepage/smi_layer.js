/**
 * SMI (Soil Moisture Index) WMS layer from IPMA. Always uses the previous day's data.
 */

const WMS_BASE =
  "https://cs2.ipma.pt/wms?dataset=smi-forecast_10p1d-continental-ecmwf&service=WMS&request=GetMap" +
  "&layers=PT%3AIPMA%3ACDG%3ALAYER%3Asmi-forecast_10p1d-continental-ecmwf_latest&styles=&format=image%2Fpng" +
  "&transparent=true&version=1.1.1&dim_layer=100&width=256&height=256&srs=EPSG%3A3857"

const SMI_SOURCE_ID = "smi-wms"
const SMI_LAYER_ID = "smi-layer"

const MONTH_NAMES_PT = [
  "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
  "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"
]

/** Format "YYYY-MM-DD" as "Dados de [dia] [mês] de [ano]" for the legend. */
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
  if (dateEl) dateEl.textContent = formatSmiDateLabel(isoDateStr)
  if (smiEl) smiEl.classList.remove("hidden")
  if (storageEl) storageEl.classList.add("hidden")
  if (pdsiEl) pdsiEl.classList.add("hidden")
}

function hideSmiLegend() {
  const smiEl = document.getElementById("legend-smi")
  const storageEl = document.getElementById("legend-storage")
  const pdsiEl = document.getElementById("legend-pdsi")
  if (smiEl) smiEl.classList.add("hidden")
  if (storageEl && (!pdsiEl || pdsiEl.classList.contains("hidden"))) storageEl.classList.remove("hidden")
}

/** Format date as YYYY-MM-DD for the given day offset (0 = today, -1 = yesterday, etc.). */
function fmtDateDay(dayOffset = 0) {
  const d = new Date()
  d.setDate(d.getDate() + dayOffset)
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, "0")
  const day = String(d.getDate()).padStart(2, "0")
  return `${y}-${m}-${day}`
}

/**
 * Build WMS GetMap URL for a given date (YYYY-MM-DD) and optional bbox.
 */
function buildWmsUrl(isoDateStr, bbox = "{bbox-epsg-3857}") {
  const timeParam = encodeURIComponent(isoDateStr + "T00:00:00.000Z")
  return `${WMS_BASE}&time=${timeParam}&bbox=${bbox}`
}

/**
 * Returns the previous day's date (YYYY-MM-DD) for the SMI layer.
 */
export function findAvailableDate() {
  return Promise.resolve(fmtDateDay(-1))
}

/**
 * Add SMI raster layer to the map. Removes existing source/layer if present.
 */
export function addSmiLayer(map, isoDateStr) {
  if (!map) return
  if (map.getLayer(SMI_LAYER_ID)) map.removeLayer(SMI_LAYER_ID)
  if (map.getSource(SMI_SOURCE_ID)) map.removeSource(SMI_SOURCE_ID)
  const tileUrl = buildWmsUrl(isoDateStr)
  map.addSource(SMI_SOURCE_ID, {
    type: "raster",
    tiles: [tileUrl],
    tileSize: 256
  })
  map.addLayer({
    id: SMI_LAYER_ID,
    type: "raster",
    source: SMI_SOURCE_ID,
    paint: { "raster-opacity": 0.9 }
  })
  showSmiLegend(isoDateStr)
}

/**
 * Remove SMI layer and source from the map.
 */
export function removeSmiLayer(map) {
  if (!map) return
  if (map.getLayer(SMI_LAYER_ID)) map.removeLayer(SMI_LAYER_ID)
  if (map.getSource(SMI_SOURCE_ID)) map.removeSource(SMI_SOURCE_ID)
  hideSmiLegend()
}
