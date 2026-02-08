import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"
import MetricsEvolution from './hooks/metrics_evolution'

let Hooks = { MetricsEvolution }

function getStorageColor(percentage) {
    console.log('getStorageColor', percentage);
    let value = Number(percentage);
    if (Number.isNaN(value)) return "#94a3b8";
    value = Math.max(0, Math.min(100, value));
    console.log('value', value);
    if (value <= 100) return "#1c9dff";
    if (value <= 80) return "#a6d8ff";
    if (value <= 50) return "#c2faaa";
    if (value <= 60) return "#ffe99c";
    if (value <= 40) return "#ffc34a";
    if (value <= 20) return "#ff675c";

    return "#16a34a";
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
        this.el.addEventListener("input", e => {
            this.pushEvent("dam_change_window", { value: this.el.value });
        })
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

window.addEventListener('phx:draw_basins', (e) => {
    topbar.hide();

    console.log('phx:draw_basins', e.detail.basins);

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
            if (!e.originalEvent.target.id.includes('marker')) {
                let basin_id = e.features[0].source;
                var a = document.getElementById('basin_detail_btn');
                a.href = "?basin_id=" + basin_id;

                document.getElementById('basin_detail_btn').click();
            }
        });

        map.on("mouseenter", fill_layer_id, () => {
            map.getCanvas().style.cursor = "pointer";
        });
    })

})

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
                name: dam.name,
                pct: dam.current_storage,
                basin: dam.basin_name
            },
            geometry: { type: 'Point', coordinates: [dam.coordinates.lon, dam.coordinates.lat] }
        });
    })

    map.addSource('dams', { type: 'geojson', data: damsGeoJSON });
    map.addLayer({
        id: 'dams-circles',
        type: 'circle',
        source: 'dams',
        paint: {
            'circle-radius': ['interpolate', ['linear'], ['zoom'], 6, 6, 10, 12],
            'circle-color': ['get', 'color'],
            'circle-stroke-width': 2,
            'circle-stroke-color': '#fff'
        }
    });
})

window.addEventListener('phx:zoom_map', (e) => {
    console.log('phx:zoom_map', e);
    var allLayers = map.getStyle().layers;

    if (e.detail.bounding_box && e.detail.site_id == null) {
        map.fitBounds(e.detail.bounding_box, { maxZoom: 8 });

        allLayers.forEach(function (item) {
            if (item.id == e.detail.basin_id + '_fill') {
                map.setPaintProperty(item.id, 'fill-opacity', areBasinsVisible ? 0.7 : 0);
            }
            else if (item.id.includes('_fill')) {
                map.setPaintProperty(item.id, 'fill-opacity', 0);
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
