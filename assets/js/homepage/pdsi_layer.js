/**
 * PDSI WMS layer from IPMA. Layer has 1-2 months delay; we probe current month
 * then -1, -2 months to find the first available date.
 */

const WMS_BASE =
  "https://cs2.ipma.pt/wms?DATASET=pdsi-p1m-continental-apuraobssup-idw&service=WMS&request=GetMap" +
  "&layers=PT:IPMA:CDG:LAYER:pdsi-p1m-continental-apuraobssup-idw&styles=&format=image%2Fpng" +
  "&transparent=true&version=1.1.1&srs=EPSG%3A3857&width=256&height=256"

/** Portugal bbox in EPSG:3857 (minx,miny,maxx,maxy) for probe requests */
const PROBE_BBOX = "-1050000,4350000,-670000,5150000"

const PDSI_SOURCE_ID = "pdsi-wms"
const PDSI_LAYER_ID = "pdsi-layer"

const MONTH_NAMES_PT = [
  "janeiro", "fevereiro", "março", "abril", "maio", "junho",
  "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"
]

/** Format "YYYY-MM-01" as "Dados de [mês] de [ano]" for the legend. */
function formatPdsiDateLabel(fmtDateStr) {
  const [y, m] = (fmtDateStr || "").split("-").map(Number)
  if (!y || !m) return ""
  const monthName = MONTH_NAMES_PT[m - 1] || fmtDateStr
  return `Dados de ${monthName} de ${y}`
}

function showPdsiLegend(fmtDateStr) {
  const dateEl = document.getElementById("legend-pdsi-date")
  const pdsiEl = document.getElementById("legend-pdsi")
  const storageEl = document.getElementById("legend-storage")
  if (dateEl) dateEl.textContent = formatPdsiDateLabel(fmtDateStr)
  if (pdsiEl) pdsiEl.classList.remove("hidden")
  if (storageEl) storageEl.classList.add("hidden")
}

function hidePdsiLegend() {
  const pdsiEl = document.getElementById("legend-pdsi")
  const storageEl = document.getElementById("legend-storage")
  if (pdsiEl) pdsiEl.classList.add("hidden")
  if (storageEl) storageEl.classList.remove("hidden")
}

/**
 * Format date as YYYY-MM-01 for the given month offset (0 = current, -1 = previous, etc.).
 */
function fmtDate(monthOffset = 0) {
  const d = new Date()
  d.setMonth(d.getMonth() + monthOffset)
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, "0")
  return `${y}-${m}-01`
}

/**
 * Build WMS GetMap URL for a given date and optional bbox (for probe). If bbox is omitted,
 * use {bbox-epsg-3857} for MapLibre tile requests.
 */
function buildWmsUrl(fmtDateStr, bbox = "{bbox-epsg-3857}") {
  const timeParam = encodeURIComponent(fmtDateStr + "T00:00:00Z")
  return `${WMS_BASE}&time=${timeParam}&bbox=${bbox}`
}

/**
 * Probe IPMA WMS for the first available date (current month, then -1, -2 months).
 * Returns a promise that resolves to "YYYY-MM-01" or the first candidate on failure.
 */
export async function findAvailableDate() {
  const candidates = [fmtDate(0), fmtDate(-1), fmtDate(-2)]
  for (const dateStr of candidates) {
    const url = buildWmsUrl(dateStr, PROBE_BBOX)
    try {
      const res = await fetch(url)
      if (!res.ok) continue
      const ct = res.headers.get("content-type") || ""
      if (!ct.toLowerCase().includes("image")) continue
      const blob = await res.blob()
      if (blob.size > 0) return dateStr
    } catch (_) {
      // try next date
    }
  }
  return candidates[0]
}

/**
 * Add PDSI raster layer to the map. Removes existing source/layer if present.
 */
export function addPdsiLayer(map, fmtDateStr) {
  if (!map) return
  if (map.getLayer(PDSI_LAYER_ID)) map.removeLayer(PDSI_LAYER_ID)
  if (map.getSource(PDSI_SOURCE_ID)) map.removeSource(PDSI_SOURCE_ID)
  const tileUrl = buildWmsUrl(fmtDateStr)
  map.addSource(PDSI_SOURCE_ID, {
    type: "raster",
    tiles: [tileUrl],
    tileSize: 256
  })
  map.addLayer({
    id: PDSI_LAYER_ID,
    type: "raster",
    source: PDSI_SOURCE_ID,
    paint: { "raster-opacity": 0.9 }
  })
  showPdsiLegend(fmtDateStr)
}

/**
 * Remove PDSI layer and source from the map.
 */
export function removePdsiLayer(map) {
  if (!map) return
  if (map.getLayer(PDSI_LAYER_ID)) map.removeLayer(PDSI_LAYER_ID)
  if (map.getSource(PDSI_SOURCE_ID)) map.removeSource(PDSI_SOURCE_ID)
  hidePdsiLegend()
}
