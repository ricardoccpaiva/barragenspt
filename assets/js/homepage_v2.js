import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"
import MetricsEvolution from './hooks/metrics_evolution'
import "./basin_chart"
import "./dam_card_charts"

let Hooks = { MetricsEvolution }

function getStorageColor(percentage) {
    let value = Number(percentage);
    if (Number.isNaN(value)) return "#94a3b8";
    value = Math.max(0, Math.min(100, value));
    if (value <= 100) return "#1c9dff";
    if (value <= 80) return "#a6d8ff";
    if (value <= 50) return "#c2faaa";
    if (value <= 60) return "#ffe99c";
    if (value <= 40) return "#ffc34a";
    if (value <= 20) return "#ff675c";

    return "#16a34a";
}

function navigateToBasin(basinId) {
    const link = document.getElementById("basinDetailLink");
    const target = `/v2/basins/${basinId}`;
    if (link) {
        link.setAttribute("href", target);
        link.click();
        return;
    }
    window.location.href = target;
}

Hooks.BasinsLayerToggle = {
    mounted() {
        var el = this.el;
        if (!el._basinsListenerAdded) {
            el._basinsListenerAdded = true;
            el.addEventListener('change', function () {
                applyBasinsLayerActive(el.checked);
            });
        }
        applyBasinsLayerActive(el.checked);
    }
}

Hooks.BasinChartTimeWindow = {
    mounted() {
        this.el.addEventListener("click", e => {
            this.pushEvent("basin_change_window", { value: this.el.value });
        })

        this.el.addEventListener("input", e => {
            this.pushEvent("basin_change_window", { value: this.el.value });
        })
    }
}

Hooks.DamChartTimeWindow = {
    mounted() {
        this.el.addEventListener("change", e => {
            this.pushEvent("dam_change_window", { value: this.el.value });
        })
    }
}

Hooks.DamChartMount = {
    mounted() {
        if (typeof window.updateDamChart === 'function' && window.chartSeries) {
            window.updateDamChart(window.chartSeries);
        }
    }
}

Hooks.DischargeChartMount = {
    mounted() {
        if (typeof window.updateDischargeChart === 'function' && window.dischargeSeries) {
            window.updateDischargeChart(window.dischargeSeries);
        }
    }
}

Hooks.DamRealtimeChartMount = {
    mounted() {
        setTimeout(function () {
            if (typeof window.updateRealtimeChart === 'function' && window.realtimeChartPayload) {
                window.updateRealtimeChart(window.realtimeChartPayload);
            }
        }, 50);
    }
}

Hooks.RiverChanged = {
    mounted() {
        this.el.addEventListener("input", e => {
            topbar.show();
            var codes = this.el.value.split('_');
            if (codes.length == 2) {
                this.pushEvent("select_river", { basin_id: codes[1], river_name: codes[0] });
            }
            else {
                this.pushEvent("select_river", {});

                var allLayers = map.getStyle().layers;
                allLayers.forEach(function (item) {
                    if (item.id.includes('rio_') && item.id.includes('_outline')) {
                        map.removeLayer(item.id);
                    }
                    else if (item.id.includes('rio_')) {
                        map.removeSource(item.id);
                    }
                })
            }
        })
    }
}

Hooks.UsageTypeChanged = {
    mounted() {
        this.el.addEventListener("change", e => {
            topbar.show();
            var usage_type = e.target.name;
            var checked = e.target.checked;

            this.pushEvent("update_selected_usage_types", { usage_type: usage_type, checked: checked });
        })
    }
}

Hooks.SearchDam = {
    mounted() {
        this.el.addEventListener("input", e => {
            this.pushEvent("search_dam", { search_term: this.el.value });
        })
    }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks, params: { _csrf_token: csrfToken } })

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

function applyBasinsLayerActive(active) {
    var style = map.getStyle();
    if (!style || !style.layers) return;
    var opacity = active ? 0.7 : 0.1;
    style.layers.forEach(function (layer) {
        if (layer.type === 'fill' && layer.id.endsWith('_fill')) {
            map.setPaintProperty(layer.id, 'fill-opacity', opacity);
        }
    });
}

window.addEventListener('phx:draw_basins', (e) => {
    topbar.hide();

    var basins = e.detail.basins;

    basins.forEach(function (item) {
        var fill_layer_id = item.id + '_fill'

        map.addSource(item.id, { type: 'geojson', data: '/geojson/' + item.name + '.geojson' });

        map.addLayer({
            'id': fill_layer_id,
            'type': 'fill',
            'source': item.id,
            'layout': {},
            'paint': {
                'fill-color': getStorageColor(item.observed_value),
                'fill-opacity': 0.7
            }
        });

        map.addLayer({
            'id': item.id + '_outline',
            'type': 'line',
            'source': item.id,
            'layout': {},
            'paint': {
                'line-color': '#000',
                'line-width': 0.5
            }
        });

        map.on('click', fill_layer_id, (e) => {
            let basin_id = e.features[0].source;

            navigateToBasin(basin_id);
        });

        map.on("mouseenter", fill_layer_id, () => {
            map.getCanvas().style.cursor = "pointer";
        });

        map.on("mouseleave", fill_layer_id, () => {
            map.getCanvas().style.cursor = "";
        });
    });

    var toggle = document.getElementById('toggleBasins');
    if (toggle) {
        applyBasinsLayerActive(toggle.checked);
        if (!toggle._basinsListenerAdded) {
            toggle._basinsListenerAdded = true;
            toggle.addEventListener('change', function () {
                applyBasinsLayerActive(toggle.checked);
            });
        }
    }
})

var DAM_ICON_ID = 'dam-icon';
var DAM_ICON_LIGHT_GRAY = '#9ca3af';
//var DAM_ICON_SVG_URL = '/images/water-svgrepo-com.svg';
var DAM_ICON_SVG_URL = '/images/pin-svgrepo-com.svg';


function ensureDamIconImage(callback) {
    if (!map.getStyle()) {
        map.once('load', function () { ensureDamIconImage(callback); });
        return;
    }
    if (map.hasImage(DAM_ICON_ID)) {
        callback(true);
        return;
    }
    // Load SVG over HTTP and register it directly as an image.
    var img = new Image();
    img.onload = function () {
        try {
            map.addImage(DAM_ICON_ID, img);
            callback(true);
        } catch (e) {
            callback(false);
        }
    };
    img.onerror = function () { callback(false); };
    img.src = DAM_ICON_SVG_URL;
}

var damsSymbolClickBound = false;

function navigateToDam(basinId, damId) {
    const link = document.getElementById('damCardPatchLink') || (function () {
        const a = document.createElement('a');
        a.id = 'damCardPatchLink';
        a.setAttribute('data-phx-link', 'patch');
        a.setAttribute('data-phx-link-state', 'push');
        a.style.display = 'none';
        document.body.appendChild(a);
        return a;
    })();
    link.href = '/v2/basins/' + basinId + '/dams/' + damId;
    link.click();
}

window.addEventListener('phx:draw_dams', (e) => {
    topbar.hide();

    var dams = e.detail.dams;
    var damsGeoJSON = {
        type: 'FeatureCollection',
        features: []
    };

    dams.forEach(function (dam) {
        damsGeoJSON.features.push({
            type: 'Feature',
            properties: {
                name: dam.dam_name || dam.name,
                pct: dam.current_storage,
                basin: dam.basin_name,
                id: dam.id,
                basin_id: dam.basin_id
            },
            geometry: { type: 'Point', coordinates: [dam.coordinates.lon, dam.coordinates.lat] }
        });
    });

    // Remove existing dams layers/source so we can re-add (e.g. on re-run)
    ['dams-ring-inner', 'dams-ring-outer', 'dams-symbol'].forEach(function (id) {
        if (map.getLayer(id)) map.removeLayer(id);
    });
    if (map.getSource('dams')) map.removeSource('dams');

    ensureDamIconImage(function (imageReady) {
        if (!imageReady) return;
        map.addSource('dams', { type: 'geojson', data: damsGeoJSON });
        map.addLayer({
            id: 'dams-symbol',
            type: 'symbol',
            source: 'dams',
            layout: {
                'icon-image': DAM_ICON_ID,
                'icon-size': 24 / 800,
                'icon-allow-overlap': true,
                'icon-ignore-placement': true
            }
        });

        if (!damsSymbolClickBound) {
            damsSymbolClickBound = true;
            map.on('click', 'dams-symbol', (ev) => {
                const props = ev.features[0].properties;
                const damId = props.id;
                const basinId = props.basin_id;
                if (damId && basinId != null) navigateToDam(basinId, damId);
            });
            map.on('mouseenter', 'dams-symbol', () => { map.getCanvas().style.cursor = 'pointer'; });
            map.on('mouseleave', 'dams-symbol', () => { map.getCanvas().style.cursor = ''; });
        }
        map.getCanvas().style.cursor = '';
    });
})

window.addEventListener('phx:zoom_map', (e) => {
    var areBasinsVisible = true;
    var allLayers = map.getStyle().layers;

    if (e.detail.bounding_box && e.detail.site_id == null) {
        map.fitBounds(e.detail.bounding_box, { maxZoom: 8 });

        allLayers.forEach(function (item) {
            if (item.id == e.detail.basin_id + '_fill') {
                map.setPaintProperty(item.id, 'fill-opacity', areBasinsVisible ? 0.7 : 0);
            }
            else if (item.id.includes('_fill')) {
                map.setPaintProperty(item.id, 'fill-opacity', 0.2);
            }
        })
    }
    else if (e.detail.bounding_box && e.detail.site_id != null) {
        allLayers.forEach(function (item) {
            if (item.id.includes('_fill')) {
                map.setPaintProperty(item.id, 'fill-opacity', 0);
            }

            if (item.id.includes('_reservoir_fill') || item.id.includes('_reservoir_outline')) {
                map.removeLayer(item.id);
            }
        })

        loadReservoir(e.detail.site_id, e.detail.current_storage_color);

        map.fitBounds(e.detail.bounding_box, { maxZoom: 12 });
    }
    else {
        map.fitBounds([
            [-9.708570, 36.682035],
            [-6.072327, 42.615949]
        ]);

        allLayers.forEach(function (item) {
            if (item.id.includes('_fill')) {
                map.setPaintProperty(item.id, 'fill-opacity', areBasinsVisible ? 0.7 : 0);
            }
        })
    }
})

window.addEventListener('phx:focus_river', (e) => {
    topbar.hide();

    document.getElementById('sidebar').classList.remove('active');

    var allLayers = map.getStyle().layers;
    var basin_id = e.detail.basin_id;
    var river_name = e.detail.river_name;

    allLayers.forEach(function (item) {
        if (item.id.includes('rio_') && item.id.includes('_outline')) {
            map.removeLayer(item.id);
        }
        else if (item.id.includes('rio_')) {
            map.removeSource(item.id);
        }

        if (item.id.includes('_fill')) {
            map.setPaintProperty(item.id, 'fill-opacity', 0.0);
        }

        if (item.id.includes(basin_id + '_fill')) {
            map.setPaintProperty(item.id, 'fill-opacity', 0.4);
        }
    })

    map.addSource('rio_' + river_name, { type: 'geojson', data: '/geojson/rivers/' + river_name + '.geojson' });
    map.addLayer({
        'id': 'rio_' + river_name + '_outline',
        'type': 'line',
        'source': 'rio_' + river_name,
        'layout': {},
        'paint': {
            'line-color': '#000',
            'line-width': 2
        }
    });
})

window.addEventListener('phx:update_basins_summary', (e) => {
    topbar.hide();

    enableTabs();
    var allLayers = map.getStyle().layers;

    allLayers.forEach(function (item) {
        if (item.id.includes('_fill')) {
            var summary_for_basin = e.detail.basins_summary.find(e => e.id + '_fill' == item.id);
            if (summary_for_basin != undefined) {
                map.setPaintProperty(item.id, 'fill-color', summary_for_basin.capacity_color);
                map.setPaintProperty(item.id, 'fill-opacity', areBasinsVisible ? 0.7 : 0);
            }
            else {
                map.setPaintProperty(item.id, 'fill-opacity', 0);
            }
        }
    })
})

window.addEventListener('phx:update_dams_visibility', (e) => {
    const allMarkers = Array.from(document.getElementsByClassName("fa-lg marker"));

    allMarkers.forEach(function (item) {
        var idParts = item.id.split('_');

        if (!e.detail.visible_site_ids.includes(idParts[1])) {
            document.getElementById(item.id).style.display = "none";
        }
        else {
            document.getElementById(item.id).style.display = "inline";
        }
    });

    topbar.hide();
})

const map = new maplibregl.Map({
    container: 'map',
    style: 'https://mapas.barragens.pt/styles/klokantech-basic/style.json',
    center: [-8, 39.69],
    zoom: 5
});

const loadReservoir = (site_id, current_storage_color) => {
    var fill_layer_id = site_id + '_reservoir_fill'
    var source_id = site_id + '_reservoir_source';

    if (map.getSource(source_id) == null) {
        map.addSource(source_id, { type: 'geojson', data: '/geojson/reservoirs/' + site_id + '.geojson' });
    }

    map.addLayer({
        'id': fill_layer_id,
        'type': 'fill',
        'source': source_id,
        'layout': {},
        'paint': {
            'fill-color': current_storage_color,
            'fill-opacity': 0.8
        }
    });

    map.addLayer({
        'id': site_id + '_reservoir_outline',
        'type': 'line',
        'source': source_id,
        'layout': {},
        'paint': {
            'line-color': '#000',
            'line-width': 1
        }
    });
}

map.addControl(new maplibregl.NavigationControl());

map.addControl(
    new maplibregl.GeolocateControl({
        positionOptions: {
            enableHighAccuracy: true
        },
        trackUserLocation: true,
        showUserHeading: true
    })
);

map.on('idle', (e) => {
    topbar.hide();
});
