/**
 * Homepage entry: LiveView socket, map, and phx:* event wiring.
 *
 * Window globals (set here or by imported modules):
 *   - window.map          MapLibre instance (used by toggles, hooks, map_events).
 *   - window.liveSocket   LiveSocket (debug: liveSocket.enableDebug(), enableLatencySim()).
 *   - window.selectBasinTab, window.updateDamChart, window.updateDischargeChart,
 *     window.updateRealtimeChart, window.toggleSidebar, window.chartSeries, etc.
 *     (set by basin_chart.js and dam_card_charts.js for LiveView hooks and DOM).
 *
 * Custom events we listen to (phx:* from server):
 *   - phx:enable_tabs           -> enableTabs()
 *   - phx:draw_basins           -> map_events (basin layers + toggle)
 *   - phx:draw_dams             -> map_events (dam circles + toggle)
 *   - phx:zoom_map              -> map_events (fitBounds, reservoir, opacity)
 *   - phx:focus_river           -> map_events (river layer)
 *   - phx:update_basins_summary -> map_events (fill colors/opacity) + enableTabs()
 *   - phx:update_dams_visibility -> map_events (filter dams-circles)
 *   - phx:draw_spain_basins, phx:remove_spain_basins -> homepage_toggles
 *   - phx:dam_chart_series, phx:dam_discharge_series, phx:dam_realtime_chart,
 *     phx:page-loading-stop -> dam_card_charts
 */
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"
import { getStorageColor } from "./utils/colors"
import { Hooks as HooksFromFile } from "./homepage_hooks"
import { applyBasinsLayerActive, applyDamsLayerActive, LayerToggleHooks, DAMS_CIRCLE_COLOR_GRAY_EXPORT } from "./homepage_toggles"
import { createMap, loadReservoir, LIGHT_STYLE, DARK_STYLE } from "./homepage/map"
import { navigateToBasin, navigateToDam } from "./homepage/navigation"
import { registerMapEvents } from "./homepage/map_events"
import "./homepage/pdsi_layer"
import "./basin_chart"
import "./dam_card_charts"

const Hooks = { ...LayerToggleHooks, ...HooksFromFile }

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks, params: { _csrf_token: csrfToken } })

topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", () => topbar.show())
window.addEventListener("phx:page-loading-stop", () => topbar.hide())
liveSocket.connect()
window.liveSocket = liveSocket

const state = { areBasinsVisible: true }

function enableTabs() {
  document.querySelectorAll("[data-basin-tab]").forEach((btn) => { btn.disabled = false })
}
window.addEventListener("phx:enable_tabs", enableTabs)

const map = createMap()
window.map = map

window.addEventListener("dark-mode-change", (e) => {
  if (map) {
    const url = e.detail.dark ? DARK_STYLE : LIGHT_STYLE;

    map.setStyle(url);
  }
})

registerMapEvents({
  map,
  topbar,
  getStorageColor,
  navigateToBasin,
  navigateToDam,
  loadReservoir: (siteId, color) => loadReservoir(map, siteId, color),
  applyBasinsLayerActive,
  applyDamsLayerActive,
  damsCircleColorGray: DAMS_CIRCLE_COLOR_GRAY_EXPORT,
  state,
  enableTabs
})
