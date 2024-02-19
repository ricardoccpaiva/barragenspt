import "../css/reports.css"
import '../node_modules/vanillajs-datepicker/dist/css/datepicker-bulma.css';
import Datepicker from '../node_modules/vanillajs-datepicker/js/Datepicker.js';
import vegaEmbed from 'vega-embed';

if (window.location.pathname == "/reports") {
    let startRangepicker;
    let endRangepicker;

    document.addEventListener('DOMContentLoaded', () => {


        var elements = document.getElementsByClassName("vega_chart_rain");

        Array.from(elements).forEach(function (element) {

            spec = {
                "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
                "data": { "url": "meteo_data?year=" + element.id + ".csv" },
                "mark": "bar",
                "width": 1100,
                "height": 50,
                "encoding": {
                    "x": {
                        "field": "date", "type": "ordinal",
                        "axis": {
                            "ticks": false,
                            "labels": false
                        }
                    },
                    "y": { "title": "", "aggregate": "mean", "field": "value" }
                }
            }

            vegaEmbed(element, spec, { actions: false })
                .then((result) => result.view)
                .catch((error) => console.error(error))
        });

        const urlParams = new URLSearchParams(window.location.search);
        const meteo_index = urlParams.get('meteo_index');
        const time_frequency = urlParams.get('time_frequency');

        if (urlParams.size > 0) {
            document.getElementById("meteo_index").value = meteo_index;
            document.getElementById("meteo_index").dispatchEvent(new Event('change'));

            document.getElementById("time_frequency").value = time_frequency;
            document.getElementById("time_frequency").dispatchEvent(new Event('change'));
        }

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

    document.getElementById('meteo_index').addEventListener("change", e => {

        if (e.currentTarget.value == "pdsi" || e.currentTarget.value == "basin_storage") {
            document.querySelectorAll("#time_frequency option").forEach(opt => {
                if (opt.value == "daily") {
                    opt.disabled = true;
                    document.getElementById("time_frequency").value = "monthly";
                    document.getElementById("time_frequency").dispatchEvent(new Event('change'));
                }
            });
        }
        else {
            if (e.currentTarget.value == "min_temperature" || e.currentTarget.value == "max_temperature") {
                document.querySelectorAll("#time_frequency option").forEach(opt => {
                    if (opt.value == "monthly") {
                        opt.disabled = true;
                        document.getElementById("time_frequency").value = "daily";
                        document.getElementById("time_frequency").dispatchEvent(new Event('change'));
                    }
                    else {
                        opt.disabled = false;
                    }
                });
            }
            else {
                document.querySelectorAll("#time_frequency option").forEach(opt => {
                    opt.disabled = false;
                });
            }
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
}