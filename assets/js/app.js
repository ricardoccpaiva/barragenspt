// We import the CSS which is extracted to its own file by esbuild.
// Remove this line if you add a your own CSS build pipeline (e.g postcss).
import "../css/app.css"

// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"

let Hooks = {}
let areBasinsVisible = true;
let areDamColorsVisible = false;
let isPdsiVisible = false;
let isSmiVisible = false;
let isRainVisible = false;
let areSpainBasinsVisible = false;

Hooks.BasinChartTimeWindow = {
    mounted() {
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

window.addEventListener(`phx:update_chart`, (e) => {
    const divId = e.detail.kind == "basin" ? "basin_chart_evo" : "dam_chart_evo";

    document.getElementById(divId).innerHTML = "";

    const chart = new G2.Chart({
        container: divId,
        autoFit: false,
        height: 220,
        width: 325,
        padding: [30, 20, 70, 30]
    });

    chart.data(e.detail.data);

    chart.scale({ value: { min: 0, max: 100 } });

    chart.tooltip({
        showCrosshairs: true,
        shared: true,
    });

    items = e.detail.lines.map(function (item) {
        return item.v;
    });

    chart
        .line()
        .position('date*value')
        .color('basin', items.reverse())
        .shape('smooth');

    chart.render();
});

window.addEventListener('phx:zoom_map', (e) => {
    var allLayers = map.getStyle().layers;

    if (e.detail.bounding_box && e.detail.site_id == null) {
        map.fitBounds(e.detail.bounding_box, { maxZoom: 8 });

        allLayers.forEach(function (item) {
            if (item.id == e.detail.basin_id + '_fill') {
                map.setPaintProperty(item.id, 'fill-opacity', areBasinsVisible ? 0.7 : 0.1);
            }
            else if (item.id.includes('_fill')) {
                map.setPaintProperty(item.id, 'fill-opacity', 0.1);
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
                map.setPaintProperty(item.id, 'fill-opacity', areBasinsVisible ? 0.7 : 0.1);
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
                map.setPaintProperty(item.id, 'fill-opacity', areBasinsVisible ? 0.7 : 0.1);
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
    const opacity = areBasinsVisible ? 0.1 : 0.7;

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

    topbar.show();
    isPdsiVisible = !isPdsiVisible;

    if (isPdsiVisible) {
        gtag('event', 'toggle_pdsi', {
            'app_name': 'barragens.pt',
            'screen_name': 'Home'
        });

        document.getElementById('pdsiLevelsLegend').style.display = "inline";

        const date = new Date();
        const fmtDate = date.getFullYear() + "-" + date.getMonth().toString().padStart(2, "0") + "-01";

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

        const fmtDate = date.getFullYear() + "-" + (date.getMonth() + 1).toString().padStart(2, "0") + "-" + date.getDate();

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
        date.setDate(date.getDate() - 2);

        const fmtDate = date.getFullYear() + "-" + (date.getMonth() + 1).toString().padStart(2, "0") + "-" + date.getDate();

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

const enableTabs = () => {
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

const loadDams = () => {
    fetch('/dams')
        .then(response => response.json())
        .then(function (response) {
            response.data.forEach(function (element) {
                el = document.createElement('div');
                innerHTML = "<a id='marker_" + element.site_id + "' class='fa-solid fa-location-dot fa-lg marker' data-phx-link='patch' ";
                innerHTML = innerHTML + " data-phx-link-state='push' href='?dam_id=" + element.site_id + "&nz" + "'</a>";
                el.innerHTML = innerHTML;

                let marker = new mapboxgl
                    .Marker(el)
                    .setLngLat([element.lon, element.lat]);

                marker.addTo(map);
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

const loadPtBasins = () => {

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
                    map.addSource(item.id, { type: 'geojson', data: '/geojson/spain/' + item.name + '.geojson' });


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
                }
            });
        });
}

mapboxgl.accessToken = document.getElementById("mapbox_token").value;
const map = new mapboxgl.Map({
    container: 'map',
    style: 'mapbox://styles/ricardoccpaiva/ckzcpwm4h001114mn112tg6fr',
    center: [-8, 39.69],
    zoom: 5
});

map.addControl(new mapboxgl.NavigationControl());

map.addControl(
    new mapboxgl.GeolocateControl({
        positionOptions: {
            enableHighAccuracy: true
        },
        trackUserLocation: true,
        showUserHeading: true
    })
);

map.on('load', function () {
    loadDams();
    if (!window.location.search.includes("?dam_id")) {
        loadPtBasins();
    }
    map.resize();
});

map.on('idle', (e) => {
    topbar.hide();
});

document.addEventListener('DOMContentLoaded', () => {
    if (getComputedStyle(document.getElementById('sidebar')).position == 'fixed') {
        introJs().setOptions({
            steps: [{
                title: 'Bem vindo!',
                intro: 'Novas funcionalidades disponíveis aqui.',
                element: document.querySelector('.menu-icon'),
            }],
            showBullets: false,
            showButtons: false,
            dontShowAgain: true,
            dontShowAgainLabel: "Não mostrar de novo"
        }).start()
    }

    // Functions to open and close a modal
    function openModal($el) {
        $el.classList.add('is-active');
    }

    function closeModal($el) {
        $el.classList.remove('is-active');
    }

    function closeAllModals() {
        (document.querySelectorAll('.modal') || []).forEach(($modal) => {
            closeModal($modal);
        });
    }

    // Add a click event on buttons to open a specific modal
    (document.querySelectorAll('.js-modal-trigger') || []).forEach(($trigger) => {
        const modal = $trigger.dataset.target;
        const $target = document.getElementById(modal);

        $trigger.addEventListener('click', () => {
            openModal($target);
        });
    });

    // Add a click event on various child elements to close the parent modal
    (document.querySelectorAll('.modal-background, .modal-close, .modal-card-head .delete, .modal-card-foot .button') || []).forEach(($close) => {
        const $target = $close.closest('.modal');

        $close.addEventListener('click', () => {
            closeModal($target);
        });
    });

    // Add a keyboard event to close all modals
    document.addEventListener('keydown', (event) => {
        const e = event || window.event;

        if (e.keyCode === 27) { // Escape key
            closeAllModals();
        }
    });
});