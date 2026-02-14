import topbar from "../../vendor/topbar"

const MAP_STYLE = "https://mapas.barragens.pt/styles/klokantech-basic/style.json"
const DEFAULT_CENTER = [-8, 39.69]
const DEFAULT_ZOOM = 5

/**
 * Creates and configures the MapLibre map. Caller must assign to window.map if needed.
 */
export function createMap() {
  const map = new maplibregl.Map({
    container: "map",
    style: MAP_STYLE,
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
  map.on("idle", () => topbar.hide())

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
