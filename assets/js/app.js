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
Hooks.ChartTimeWindow = {
    mounted() {
        this.el.addEventListener("input", e => {
            this.pushEvent("change_window", { value: this.el.value });
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
    document.getElementById("c1").innerHTML = "";
    const chart = new G2.Chart({
        container: 'c1',
        autoFit: false,
        height: 325,
        width: 560,
        padding: [30, 20, 70, 30]
    });

    chart.data(e.detail.data);

    chart.scale({ value: { min: 0, max: 100 } });

    items = e.detail.lines.map(function (item) {
        return item.v;
    });

    chart
        .line()
        .position('date*value')
        .color('basin', items.reverse())
        .shape('smooth');

    chart.render();

    colors = chart.geometries[0].elements.map(function (item) {
        return { color: item.model.color, id: item.model.data[0].basin_id }
    });
})

window.addEventListener('phx:zoom_map', (e) => {
    if (e.detail.bounding_box) {
        map.fitBounds(e.detail.bounding_box, { maxZoom: 8 });
    }
    else if (e.detail.center) {
        map.flyTo({
            center: e.detail.center,
            essential: true,
            zoom: 12,
            speed: 2
        });
    }
    else {
        map.flyTo({
            center: [-8, 39.59],
            essential: true,
            zoom: 6,
            speed: 2
        });
    }
})

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
    tabs[0].click();
}

const loadDams = async () => {
    const response = await fetch('/dams');
    const damsCoords = await response.json();
    damsCoords.data.forEach(function (element) {
        el = document.createElement('div');
        innerHTML = "<a class='fa-solid fa-location-dot fa-lg marker' data-phx-link='patch' ";
        innerHTML = innerHTML + " data-phx-link-state='push' href='/dam/" + element.site_id + "?nz" + "'</a>";
        el.innerHTML = innerHTML;

        new mapboxgl
            .Marker(el)
            .setLngLat([element.lon, element.lat])
            .addTo(map);
    });
}

const loadBasins = async () => {
    const response = await fetch('/basins');
    const basins = await response.json();
    basins.data.forEach(function (item) {
        map.addSource(item.name, { type: 'geojson', data: '/geojson/' + item.name + '.geojson' });

        map.addLayer({
            'id': item.name,
            'type': 'fill',
            'source': item.name,
            'layout': {},
            'paint': {
                'fill-color': item.capacity_color,
                'fill-opacity': 0.7
            }
        });

        map.addLayer({
            'id': item.name + '_outline',
            'type': 'line',
            'source': item.name,
            'layout': {},
            'paint': {
                'line-color': '#000',
                'line-width': 0.5
            }
        });
    });

}

mapboxgl.accessToken = document.getElementById("mapbox_token").value;
const map = new mapboxgl.Map({
    container: 'map',
    style: 'mapbox://styles/ricardoccpaiva/ckzcpwm4h001114mn112tg6fr',
    center: [-8, 39.69],
    zoom: 4
});

map.addControl(new mapboxgl.NavigationControl());

map.on('load', function () {
    map.resize();
    loadDams();
    loadBasins();
});