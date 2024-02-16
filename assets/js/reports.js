import "../css/reports.css"
import '../node_modules/vanillajs-datepicker/dist/css/datepicker-bulma.css';

import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"
import Datepicker from '../node_modules/vanillajs-datepicker/js/Datepicker.js';

document.addEventListener('DOMContentLoaded', () => {
    const urlParams = new URLSearchParams(window.location.search);
    const meteo_index = urlParams.get('meteo_index');
    const time_frequency = urlParams.get('time_frequency');

    document.getElementById("meteo_index").value = meteo_index;
    document.getElementById("meteo_index").dispatchEvent(new Event('change'));

    document.getElementById("time_frequency").value = time_frequency;
    document.getElementById("time_frequency").dispatchEvent(new Event('change'));

    const startElem = document.getElementById('start');
    const endElem = document.getElementById('end');

    let pickLevel = (startElem.value.length == 4 || startElem.value == "") ? 2 : 1;
    let format = (startElem.value.length == 4 || startElem.value == "") ? "yyyy" : "mm/yyyy";

    startRangepicker = new Datepicker(startElem, {
        autohide: true,
        format: format,
        orientation: 'bottom left',
        language: 'pt',
        pickLevel: pickLevel
    });

    endRangepicker = new Datepicker(endElem, {
        autohide: true,
        format: format,
        orientation: 'bottom left',
        language: 'pt',
        pickLevel: pickLevel
    });
});

let startRangepicker;
let endRangepicker;

let Hooks = {}
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks, params: { _csrf_token: csrfToken } })

Hooks.MeteoIndexChanged = {
    mounted() {
        this.el.addEventListener("input", e => {
            var codes = this.el.value;
        })
    }
}

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

document.getElementById('meteo_index').addEventListener("change", e => {
    if (e.currentTarget.value == "pdsi") {
        document.querySelectorAll("#time_frequency option").forEach(opt => {
            if (opt.value == "daily") {
                opt.disabled = true;
                document.getElementById("time_frequency").value = "monthly";
                document.getElementById("time_frequency").dispatchEvent(new Event('change'));
            }
        });
    }
    else {
        document.querySelectorAll("#time_frequency option").forEach(opt => {
            opt.disabled = false;
        });
    }
});

document.getElementById('time_frequency').addEventListener("change", e => {
    let pickLevel = e.currentTarget.value == "monthly" ? 2 : 1;
    let format = e.currentTarget.value == "monthly" ? "yyyy" : "mm/yyyy";

    startRangepicker.setOptions({
        pickLevel: pickLevel,
        format: format
    });

    endRangepicker.setOptions({
        pickLevel: pickLevel,
        format: format
    });

    startRangepicker.refresh();
    endRangepicker.refresh();
});