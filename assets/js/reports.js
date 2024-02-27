import "../css/reports.css"
import '../node_modules/vanillajs-datepicker/dist/css/datepicker-bulma.css';
import Datepicker from '../node_modules/vanillajs-datepicker/js/Datepicker.js';
import { build_pdsi_spec, build_precipitation_spec, build_temperature_spec, draw_spec } from "./vega_lite_specs.js";

if (window.location.pathname == "/reports") {
    let startRangepicker;
    let endRangepicker;

    window.onload = function () {
        const urlParams = new URLSearchParams(window.location.search);
        const meteo_index = urlParams.get('meteo_index');
        const time_frequency = urlParams.get('time_frequency');
        const viz_type = urlParams.get('viz_type');
        const correlate = urlParams.get('correlate');

        if (urlParams.size > 0) {
            document.getElementById("chk_correlate").checked = (correlate == "on");

            document.getElementById("meteo_index").value = meteo_index;
            document.getElementById("meteo_index").dispatchEvent(new Event('change'));

            document.getElementById("time_frequency").value = time_frequency;
            document.getElementById("time_frequency").dispatchEvent(new Event('change'));

            document.getElementById("viz_type").value = viz_type;
            document.getElementById("viz_type").dispatchEvent(new Event('change'));
        }

        if (document.getElementById("chk_correlate").checked) {
            var elements = document.getElementsByClassName("vega_chart_rain");

            Array.from(elements).forEach(function (element) {
                let spec = build_precipitation_spec(element.id);
                draw_spec(element, spec);
            });
        }

        if (viz_type == 'chart') {
            if (meteo_index.includes("temperature")) {
                var elements = document.getElementsByClassName("vega_chart_temperature");

                Array.from(elements).forEach(function (element) {

                    var chartContainer = document.getElementById("tbl_magic");
                    var containerWidth = chartContainer.offsetWidth * 0.92;
                    let [year, month] = element.id.split('-');

                    let spec = build_temperature_spec(year, month, meteo_index, containerWidth);

                    draw_spec(element, spec);
                });
            }
            else {
                var elements = document.getElementsByClassName("vega_chart_rain");

                Array.from(elements).forEach(function (element) {
                    var chartContainer = document.getElementById("tbl_magic");
                    var containerWidth = chartContainer.offsetWidth * 0.92;

                    let spec = build_pdsi_spec(meteo_index, element.id, containerWidth);

                    draw_spec(element, spec);
                });
            }
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
    };

    document.getElementById('viz_type').addEventListener("change", e => {
        if (e.currentTarget.value == "chart") {
            document.getElementById("viz_mode_div").classList.add("hidden");
            document.getElementById("chk_correlate").checked = false;
            document.getElementById("chk_correlate_div").classList.add("hidden");
        }
        else {
            document.getElementById("viz_mode_div").classList.remove("hidden");
            document.getElementById("chk_correlate_div").classList.remove("hidden");
        }

    });

    document.getElementById('meteo_index').addEventListener("change", e => {

        if (e.currentTarget.value == "pdsi" || e.currentTarget.value == "basin_storage") {
            document.getElementById("chk_correlate").disabled = false;
            document.querySelectorAll("#time_frequency option").forEach(opt => {
                if (opt.value == "daily") {
                    opt.disabled = true;
                    document.getElementById("time_frequency").value = "monthly";
                    document.getElementById("time_frequency").dispatchEvent(new Event('change'));
                }
                else {
                    opt.disabled = false;
                }
            });
        }
        else {
            document.getElementById("chk_correlate").disabled = true;
            document.getElementById("chk_correlate").checked = false;
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