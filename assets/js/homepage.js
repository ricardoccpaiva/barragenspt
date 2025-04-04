import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"
import MetricsEvolution from './hooks/metrics_evolution'

let Hooks = { MetricsEvolution }
let areBasinsVisible = true;
let areDamColorsVisible = false;
let isPdsiVisible = false;
let isSmiVisible = false;
let isRainVisible = false;
let areSpainBasinsVisible = false;
let intervalId = 0;
let yearIndex = 0;
let monthIndex = 0;
let years = Array.from({ length: 2023 - 2020 + 1 }, (_, index) => 2020 + index);
let months = Array.from({ length: 12 - 1 + 1 }, (_, index) => 1 + index);

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

window.addEventListener(`phx:enable_tabs`, (e) => {
    enableTabs();
})

window.addEventListener('phx:zoom_map', (e) => {
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

map.on('load', function () {
    loadDams(map);
    if (!window.location.search.includes("?dam_id")) {
        loadPtBasins(map);
    }
    map.resize();
});

map.on('idle', (e) => {
    topbar.hide();
});

document.getElementById('switchBasins').addEventListener("click", e => {
    if (isSmiVisible) {
        document.getElementById('switchSMI').click();
    }
    if (isPdsiVisible) {
        document.getElementById('switchPDSI').click();
    }
    if (isRainVisible) {
        document.getElementById('switchRain').click();
    }

    document.getElementById('sidebar').classList.remove('active');

    const allLayers = map.getStyle().layers;
    const opacity = areBasinsVisible ? 0 : 0.7;

    allLayers.forEach(function (item) {
        if ((item.id.includes('_fill') && !item.id.includes('_fill_es')) || (item.id.includes('_fill_es') && areSpainBasinsVisible)) {
            map.setPaintProperty(item.id, 'fill-opacity', opacity);
        }
    });

    areBasinsVisible = !areBasinsVisible;

    if (areBasinsVisible) {
        gtag('event', 'toggle_basins', {
            'app_name': 'barragens.pt',
            'screen_name': 'Home'
        });
        document.getElementById('damsLevelLegend').style.display = "inline";
    }
    else {
        document.getElementById('damsLevelLegend').style.display = "none";
    }
});

document.getElementById('switchPDSI').addEventListener("click", e => {
    if (areBasinsVisible) {
        document.getElementById('switchBasins').click();
    }
    if (isSmiVisible) {
        document.getElementById('switchSMI').click();
    }

    if (isRainVisible) {
        document.getElementById('switchRain').click();
    }

    topbar.show();
    isPdsiVisible = !isPdsiVisible;

    if (isPdsiVisible) {
        gtag('event', 'toggle_pdsi', {
            'app_name': 'barragens.pt',
            'screen_name': 'Home'
        });

        document.getElementById('pdsiLevelsLegend').style.display = "inline";

        const date = new Date();
        date.setMonth(date.getMonth());
        const fmtDate = date.getFullYear() + "-" + date.getMonth().toString().padStart(2, "0") + "-01";

        document.getElementById("pdsiLegendDate").innerHTML = "01/" + (date.getMonth() + 1).toString().padStart(2, "0") + "/" + date.getFullYear();

        map.addSource('wms-pdsi-source', {
            'type': 'raster',
            'tiles': [
                "https://mapservices.ipma.pt/observations/climate/PalmerDroughtSeverityIndex/wms?service=WMS&request=GetMap&layers=mpdsi.obsSup.monthly.vector.conc&styles=&format=image%2Fpng&transparent=true&version=1.1.1&time=" + fmtDate + "T00%3A00%3A00Z&srs=EPSG%3A3857&bbox={bbox-epsg-3857}&width=256&height=256"
            ],
            'tileSize': 256
        });
        map.addLayer(
            {
                'id': 'wms-pdsi-layer',
                'type': 'raster',
                'source': 'wms-pdsi-source',
                'paint': {}
            },
            'building'
        );
    }
    else {
        document.getElementById('pdsiLevelsLegend').style.display = "none";

        map.removeLayer('wms-pdsi-layer');
        map.removeSource('wms-pdsi-source');
    }

    document.getElementById('sidebar').classList.remove('active');
});

document.getElementById('switchSMI').addEventListener("click", e => {
    if (areBasinsVisible) {
        document.getElementById('switchBasins').click();
    }
    if (isPdsiVisible) {
        document.getElementById('switchPDSI').click();
    }

    if (isRainVisible) {
        document.getElementById('switchRain').click();
    }

    topbar.show();
    isSmiVisible = !isSmiVisible;

    if (isSmiVisible) {
        gtag('event', 'toggle_smi', {
            'app_name': 'barragens.pt',
            'screen_name': 'Home'
        });
        document.getElementById('smiLevelsLegend').style.display = "inline";

        const date = new Date();
        date.setDate(date.getDate() - 1);

        document.getElementById("smiLegendDate").innerHTML = date.getDate() + "/" + (date.getMonth() + 1).toString().padStart(2, "0") + "/" + date.getFullYear();

        const fmtDate = date.getFullYear() + "-" + (date.getMonth() + 1).toString().padStart(2, "0") + "-" + date.getDate().toString().padStart(2, "0");

        map.addSource('wms-smi-source', {
            'type': 'raster',
            'tiles': [
                "https://mapservices.ipma.pt/observations/climate/SoilMoistureIndex/wms?service=WMS&request=GetMap&layers=smi.obsRem.daily.grid.continental.timeDimension&styles=&format=image/png&transparent=true&version=1.1.1&time=" + fmtDate + "T00:00:00Z&width=256&height=256&srs=EPSG:3857&bbox={bbox-epsg-3857}"
            ],
            'tileSize': 256
        });
        map.addLayer(
            {
                'id': 'wms-smi-layer',
                'type': 'raster',
                'source': 'wms-smi-source',
                'paint': {}
            },
            'building'
        );
    }
    else {
        document.getElementById('smiLevelsLegend').style.display = "none";

        map.removeLayer('wms-smi-layer');
        map.removeSource('wms-smi-source');
    }

    document.getElementById('sidebar').classList.remove('active');
});

document.getElementById('switchRain').addEventListener("click", e => {
    if (areBasinsVisible) {
        document.getElementById('switchBasins').click();
    }
    if (isPdsiVisible) {
        document.getElementById('switchPDSI').click();
    }
    if (isSmiVisible) {
        document.getElementById('switchSMI').click();
    }

    topbar.show();
    isRainVisible = !isRainVisible;

    if (isRainVisible) {
        gtag('event', 'toggle_rain', {
            'app_name': 'barragens.pt',
            'screen_name': 'Home'
        });
        document.getElementById('rainLevelsLegend').style.display = "inline";

        const date = new Date();
        date.setDate(date.getDate() - 1);

        document.getElementById("rainLegendDate").innerHTML = date.getDate() + "/" + (date.getMonth() + 1).toString().padStart(2, "0") + "/" + date.getFullYear();

        const fmtDate = date.getFullYear() + "-" + (date.getMonth() + 1).toString().padStart(2, "0") + "-" + date.getDate().toString().padStart(2, "0");

        map.addSource('wms-rain-source', {
            'type': 'raster',
            'tiles': [
                "https://mapservices.ipma.pt/observations/climate/precipitation/wms?service=WMS&request=GetMap&layers=mrrto.obsSup.daily.vector.conc&styles=&format=image/png&transparent=true&version=1.1.1&time=" + fmtDate + "T00:00:00Z&width=256&height=256&srs=EPSG:3857&bbox={bbox-epsg-3857}"
            ],
            'tileSize': 256
        });
        map.addLayer(
            {
                'id': 'wms-rain-layer',
                'type': 'raster',
                'source': 'wms-rain-source',
                'paint': {}
            },
            'building'
        );
    }
    else {
        document.getElementById('rainLevelsLegend').style.display = "none";

        map.removeLayer('wms-rain-layer');
        map.removeSource('wms-rain-source');
    }

    document.getElementById('sidebar').classList.remove('active');
});

document.getElementById('switchSpainBasins').addEventListener("click", e => {
    topbar.show();
    areSpainBasinsVisible = !areSpainBasinsVisible;

    if (areSpainBasinsVisible) {
        gtag('event', 'toggle_spain_basins', {
            'app_name': 'barragens.pt',
            'screen_name': 'Home'
        });

        loadEsBasins().then(() => {
            map.fitBounds([
                [-10.0186, 35.588],
                [3.8135, 43.9644]
            ]);

            document.getElementById('sidebar').classList.remove('active');
            topbar.hide();
        });
    }
    else {
        map.fitBounds([
            [-9.708570, 36.682035],
            [-6.072327, 42.615949]
        ]);
        removeEsBasinLayers();
    }
});

document.getElementById('switchDams').addEventListener("click", e => {
    document.getElementById('sidebar').classList.remove('active');

    fetch('/dams')
        .then(response => response.json())
        .then(function (response) {
            response.data.forEach(function (element) {
                let marker = document.getElementById("marker_" + element.site_id);
                marker.style.color = areDamColorsVisible ? element.current_storage_color : "gray";
            });
        });

    areDamColorsVisible = !areDamColorsVisible;
});

export const enableTabs = () => {
    let tabs = document.querySelectorAll('.tabs li');
    let tabsContent = document.querySelectorAll('.tab-content');

    let deactvateAllTabs = function () {
        tabs.forEach(function (tab) {
            tab.classList.remove('is-active');
        });
    };

    let hideTabsContent = function () {
        tabsContent.forEach(function (tabContent) {
            tabContent.classList.remove('is-active');
        });
    };

    let activateTabsContent = function (tab) {
        tabsContent[getIndex(tab)].classList.add('is-active');
    };

    let getIndex = function (el) {
        return [...el.parentElement.children].indexOf(el);
    };

    tabs.forEach(function (tab) {
        tab.addEventListener('click', function () {
            deactvateAllTabs();
            hideTabsContent();
            tab.classList.add('is-active');
            activateTabsContent(tab);
        });
    });

    if (tabs.length > 0) {
        tabs[0].click();
    }
}

export const loadDams = () => {
    fetch('/dams')
        .then(response => response.json())
        .then(function (response) {
            response.data.forEach(function (element) {
                var parentDiv = document.createElement('div');

                var childLink = document.createElement('a');
                childLink.id = 'marker_' + element.site_id;
                childLink.classList.add("fa-solid");
                childLink.classList.add("fa-location-dot");
                childLink.classList.add("fa-lg");
                childLink.classList.add("marker");
                childLink.setAttribute('data-phx-link', 'patch');
                childLink.setAttribute('data-phx-link-state', 'push');
                childLink.setAttribute('href', '?dam_id=' + element.site_id + '&nz');

                parentDiv.appendChild(childLink);

                let marker = new maplibregl
                    .Marker({ element: parentDiv })
                    .setLngLat([element.lon, element.lat])
                    .addTo(map)
            });
        });
}

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

export const loadPtBasins = () => {

    fetch('/basins?country=pt')
        .then(response => response.json())
        .then(function (response) {
            response.data.forEach(function (item) {

                var fill_layer_id = item.id + '_fill'

                map.addSource(item.id, { type: 'geojson', data: '/geojson/' + item.name + '.geojson' });

                map.addLayer({
                    'id': fill_layer_id,
                    'type': 'fill',
                    'source': item.id,
                    'layout': {},
                    'paint': {
                        'fill-color': item.capacity_color,
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
            });
        });
}

const removeEsBasinLayers = () => {
    const allLayers = map.getStyle().layers;

    allLayers.forEach(function (item) {
        if (item.id.includes('_fill_es') || item.id.includes('_outline_es')) {
            map.removeLayer(item.id);
        }
    });
}

async function loadEsBasins() {
    await fetch('/basins?country=es')
        .then(response => response.json())
        .then(function (response) {
            response.data.forEach(function (item) {
                {
                    var fill_layer_id = item.id + '_fill_es'
                    if (map.getSource(item.id) == null) {
                        map.addSource(item.id, { type: 'geojson', data: '/geojson/spain/' + item.name + '.geojson' });
                    }

                    map.addLayer({
                        'id': fill_layer_id,
                        'type': 'fill',
                        'source': item.id,
                        'layout': {},
                        'paint': {
                            'fill-color': item.capacity_color,
                            'fill-opacity': 0.7
                        }
                    });

                    map.addLayer({
                        'id': item.id + '_outline_es',
                        'type': 'line',
                        'source': item.id,
                        'layout': {},
                        'paint': {
                            'line-color': '#000',
                            'line-width': 1
                        }
                    });

                    map.on('click', fill_layer_id, (e) => {
                        if (!e.originalEvent.target.id.includes('marker')) {
                            let basin_id = e.features[0].source;
                            var a = document.getElementById('basin_detail_btn');
                            a.href = "?basin_id=" + basin_id + "&country=es";

                            document.getElementById('basin_detail_btn').click();
                        }
                    });

                    map.on("mouseenter", fill_layer_id, () => {
                        map.getCanvas().style.cursor = "pointer";
                    });
                }
            });
        });
}