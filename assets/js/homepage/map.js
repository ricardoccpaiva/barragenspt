import topbar from "../../vendor/topbar"

export const LIGHT_STYLE = "https://mapas.barragens.pt/styles/klokantech-basic/style.json"
export const DARK_STYLE = "https://mapas.barragens.pt/styles/positron/style.json"
const DEFAULT_CENTER = [-8, 39.69]
const DEFAULT_ZOOM = 5

function getStyleUrl() {
  return document.documentElement.classList.contains("dark") ? DARK_STYLE : LIGHT_STYLE
}

/**
 * Creates and configures the MapLibre map. Caller must assign to window.map if needed.
 */
export function createMap() {
  const map = new maplibregl.Map({
    container: "map",
    style: getStyleUrl(),
    center: DEFAULT_CENTER,
    zoom: DEFAULT_ZOOM
  })

  map.addControl(new maplibregl.NavigationControl())
  map.addControl(
    new maplibregl.GeolocateControl({
      positionOptions: { enableHighAccuracy: true },
      trackUserLocation: true,
      showUserHeading: true
    })
  )
  map.on("idle", () => {
    topbar.hide()
    document.documentElement.classList.add("map-loaded")
  })

  return map
}

/**
 * Adds reservoir fill and outline layers for a site.
 */
export function loadReservoir(map, siteId, currentStorageColor) {
  const fillLayerId = siteId + "_reservoir_fill"
  const sourceId = siteId + "_reservoir_source"

  if (map.getSource(sourceId) == null) {
    map.addSource(sourceId, {
      type: "geojson",
      data: "/geojson/reservoirs/" + siteId + ".geojson"
    })
  }

  map.addLayer({
    id: fillLayerId,
    type: "fill",
    source: sourceId,
    layout: {},
    paint: {
      "fill-color": currentStorageColor,
      "fill-opacity": 0.8
    }
  })
  map.addLayer({
    id: siteId + "_reservoir_outline",
    type: "line",
    source: sourceId,
    layout: {},
    paint: { "line-color": "#000", "line-width": 1 }
  })
}
