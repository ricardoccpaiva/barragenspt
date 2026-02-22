/**
 * Runs fn when the map style is loaded (immediately if already loaded, else on "load").
 */
function whenStyleLoaded(map, fn) {
  if (map.isStyleLoaded()) {
    fn()
  } else {
    map.once("load", fn)
  }
}

/**
 * Registers all phx:* custom event listeners for the map.
 * Dependencies are passed so this module stays testable and avoids globals.
 */
export function registerMapEvents(deps) {
  const {
    map,
    topbar,
    getStorageColor,
    navigateToBasin,
    navigateToDam,
    loadReservoir,
    applyBasinsLayerActive,
    applyDamsLayerActive,
    damsCircleColorGray,
    state,
    enableTabs
  } = deps

  let damsSymbolClickBound = false

  window.addEventListener("phx:draw_basins", (e) => {
    topbar.hide()
    whenStyleLoaded(map, () => {
      const basins = e.detail.basins
      basins.forEach((item) => {
        const fillLayerId = item.id + "_fill"
        map.addSource(item.id, { type: "geojson", data: "/geojson/" + item.name + ".geojson" })
        map.addLayer({
          id: fillLayerId,
          type: "fill",
          source: item.id,
          layout: {},
          paint: {
            "fill-color": getStorageColor(item.observed_value),
            "fill-opacity": 0.7
          }
        })
        map.addLayer({
          id: item.id + "_outline",
          type: "line",
          source: item.id,
          layout: {},
          paint: { "line-color": "#000", "line-width": 0.5 }
        })
        map.on("click", fillLayerId, (ev) => {
          navigateToBasin(ev.features[0].source)
        })
        map.on("mouseenter", fillLayerId, () => { map.getCanvas().style.cursor = "pointer" })
        map.on("mouseleave", fillLayerId, () => { map.getCanvas().style.cursor = "" })
      })
      window.cachedBasinsSummary = basins.map((item) => ({
        id: item.id,
        capacity_color: getStorageColor(item.observed_value)
      }))
      const toggle = document.getElementById("toggleBasins")
      if (toggle) {
        toggle.checked = true
        applyBasinsLayerActive(true)
      }
    })
  })

  window.addEventListener("phx:draw_dams", (e) => {
    topbar.hide()
    whenStyleLoaded(map, () => {
      const dams = e.detail.dams
      const damsGeoJSON = { type: "FeatureCollection", features: [] }
      dams.forEach((dam) => {
        damsGeoJSON.features.push({
          type: "Feature",
          properties: {
            name: dam.dam_name || dam.name,
            pct: dam.current_storage,
            basin: dam.basin_name,
            id: dam.id,
            basin_id: dam.basin_id
          },
          geometry: { type: "Point", coordinates: [dam.coordinates.lon, dam.coordinates.lat] }
        })
      })
        ;["dams-ring-inner", "dams-ring-outer", "dams-circles"].forEach((id) => {
          if (map.getLayer(id)) map.removeLayer(id)
        })
      if (map.getSource("dams")) map.removeSource("dams")
      map.addSource("dams", { type: "geojson", data: damsGeoJSON })
      map.addLayer({
        id: "dams-circles",
        type: "circle",
        source: "dams",
        paint: {
          "circle-radius": 6,
          "circle-color": damsCircleColorGray,
          "circle-stroke-width": 2,
          "circle-stroke-color": "#fff"
        }
      })
      const toggle = document.getElementById("toggleDams")
      if (toggle) {
        applyDamsLayerActive(toggle.checked)
        if (!toggle._damsListenerAdded) {
          toggle._damsListenerAdded = true
          toggle.addEventListener("change", () => applyDamsLayerActive(toggle.checked))
        }
      }
      if (!damsSymbolClickBound) {
        damsSymbolClickBound = true
        map.on("click", "dams-circles", (ev) => {
          const props = ev.features[0].properties
          if (props.id && props.basin_id != null) navigateToDam(props.basin_id, props.id)
        })
        map.on("mouseenter", "dams-circles", () => { map.getCanvas().style.cursor = "pointer" })
        map.on("mouseleave", "dams-circles", () => { map.getCanvas().style.cursor = "" })
      }
    })
  })

  window.addEventListener("phx:zoom_map", (e) => {
    whenStyleLoaded(map, () => {
      const allLayers = map.getStyle().layers
      if (e.detail.bounding_box && e.detail.site_id == null) {
        map.fitBounds(e.detail.bounding_box, { maxZoom: 8 })
        allLayers.forEach((item) => {
          if (item.id === e.detail.basin_id + "_fill") {
            map.setPaintProperty(item.id, "fill-opacity", state.areBasinsVisible ? 0.7 : 0)
          } else if (item.id.includes("_fill")) {
            map.setPaintProperty(item.id, "fill-opacity", 0.2)
          }
        })
      } else if (e.detail.bounding_box && e.detail.site_id != null) {
        allLayers.forEach((item) => {
          if (item.id.includes("_fill")) map.setPaintProperty(item.id, "fill-opacity", 0)
          if (item.id.includes("_reservoir_fill") || item.id.includes("_reservoir_outline")) {
            map.removeLayer(item.id)
          }
        })
        loadReservoir(map, e.detail.site_id, e.detail.current_storage_color)
        map.fitBounds(e.detail.bounding_box, { maxZoom: 12 })
      } else {
        map.fitBounds([
          [-17.30384751295111, 36.50952345455322],
          [-2.262873003102527, 42.457622802586286]
        ])
        allLayers.forEach((item) => {
          if (item.id.includes("_fill")) {
            map.setPaintProperty(item.id, "fill-opacity", state.areBasinsVisible ? 0.7 : 0)
          }
        })
      }
    })
  })

  window.addEventListener("phx:focus_river", (e) => {
    topbar.hide()
    const sidebar = document.getElementById("sidebar")
    if (sidebar) sidebar.classList.remove("active")
    whenStyleLoaded(map, () => {
      const allLayers = map.getStyle().layers
      const basinId = e.detail.basin_id
      const riverName = e.detail.river_name
      allLayers.forEach((item) => {
        if (item.id.includes("rio_") && item.id.includes("_outline")) map.removeLayer(item.id)
        else if (item.id.includes("rio_")) map.removeSource(item.id)
        if (item.id.includes("_fill")) map.setPaintProperty(item.id, "fill-opacity", 0)
        if (item.id.includes(basinId + "_fill")) map.setPaintProperty(item.id, "fill-opacity", 0.4)
      })
      map.addSource("rio_" + riverName, {
        type: "geojson",
        data: "/geojson/rivers/" + riverName + ".geojson"
      })
      map.addLayer({
        id: "rio_" + riverName + "_outline",
        type: "line",
        source: "rio_" + riverName,
        layout: {},
        paint: { "line-color": "#000", "line-width": 2 }
      })
    })
  })

  window.addEventListener("phx:update_basins_summary", (e) => {
    topbar.hide()
    enableTabs()
    const basinsSummary = e.detail.basins_summary
    if (basinsSummary) window.cachedBasinsSummary = basinsSummary
    whenStyleLoaded(map, () => {
      const allLayers = map.getStyle().layers
      allLayers.forEach((item) => {
        if (!item.id.includes("_fill")) return
        const summaryForBasin = basinsSummary.find((b) => b.id + "_fill" === item.id)
        if (summaryForBasin != null) {
          map.setPaintProperty(item.id, "fill-color", summaryForBasin.capacity_color)
          map.setPaintProperty(item.id, "fill-opacity", state.areBasinsVisible ? 0.7 : 0)
        } else {
          map.setPaintProperty(item.id, "fill-opacity", 0)
        }
      })
    })
  })

  window.addEventListener("phx:draw_alerts_layer", (e) => {
    topbar.hide()
    const alerts = e.detail.alerts || []
    const alertByBasinId = Object.fromEntries(alerts.map((a) => [String(a.basin_id), a]))
    const opacity = state.areBasinsVisible ? 0.7 : 0
    whenStyleLoaded(map, () => {
      const style = map.getStyle()
      if (!style || !style.layers) return
      style.layers.forEach((layer) => {
        if (!layer.id.endsWith("_fill") || layer.id.includes("_reservoir")) return
        const basinId = layer.id.replace(/_fill$/, "")
        const alert = alertByBasinId[basinId]
        if (alert) {
          map.setPaintProperty(layer.id, "fill-color", alert.color)
          map.setPaintProperty(layer.id, "fill-opacity", opacity)
        }
        else {
          map.setPaintProperty(layer.id, "fill-color", "#2eb1d3")
          map.setPaintProperty(layer.id, "fill-opacity", opacity)
        }
      })
      const legendAlerts = document.getElementById("legend-alerts")
      const legendStorage = document.getElementById("legend-storage")
      const legendPdsi = document.getElementById("legend-pdsi")
      const legendSmi = document.getElementById("legend-smi")
      const legendRain = document.getElementById("legend-rain")
      if (legendAlerts) legendAlerts.classList.remove("hidden")
      if (legendStorage) legendStorage.classList.add("hidden")
      if (legendPdsi) legendPdsi.classList.add("hidden")
      if (legendSmi) legendSmi.classList.add("hidden")
      if (legendRain) legendRain.classList.add("hidden")
    })
  })

  window.addEventListener("phx:update_dams_visibility", (e) => {
    if (!map.getLayer("dams-circles")) return
    const visible = e.detail.visible_site_ids || []
    map.setFilter("dams-circles", ["in", ["get", "id"], ["literal", visible]])
    topbar.hide()
  })
}
