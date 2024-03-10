import "../css/reports.css"
import '../node_modules/vanillajs-datepicker/dist/css/datepicker-bulma.css';
import Datepicker from '../node_modules/vanillajs-datepicker/js/Datepicker.js';
import {
    build_pdsi_spec,
    build_daily_precipitation_for_one_year_spec,
    build_temperature_spec,
    build_monthly_precipitation_spec,
    build_daily_precipitation_spec,
    draw_spec
} from "./vega_lite_specs.js";

if (window.location.pathname == "/reports") {
    let startRangepicker;
    let endRangepicker;

    window.onload = function () {
        const urlParams = new URLSearchParams(window.location.search);
        const meteo_index = urlParams.get('meteo_index');
        const time_frequency = urlParams.get('time_frequency');
        const viz_type = urlParams.get('viz_type');
        const correlate = urlParams.get('correlate');
        const compare_with_ref = urlParams.get('compare_with_ref');
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

        if (urlParams.size > 0) {
            document.getElementById("chk_correlate").checked = (correlate == "on");
            document.getElementById("compare_with_ref").checked = (compare_with_ref == "on");

            document.getElementById("meteo_index").value = meteo_index;
            document.getElementById("meteo_index").dispatchEvent(new Event('change'));

            document.getElementById("time_frequency").value = time_frequency;
            document.getElementById("time_frequency").dispatchEvent(new Event('change'));

            document.getElementById("viz_type").value = viz_type;
            document.getElementById("viz_type").dispatchEvent(new Event('change'));
        }

        if (document.getElementById("chk_correlate").checked) {
            var elements = document.getElementsByClassName("vega_chart");
            var chartContainer = document.getElementById("tbl_magic");

            Array.from(elements).forEach(function (element) {
                let spec = build_daily_precipitation_for_one_year_spec(element.id);

                draw_spec(element, spec);
            });
        }

        if (viz_type == 'chart') {
            var elements = document.getElementsByClassName("vega_chart");
            var chartContainer = document.getElementById("tbl_magic");
            var containerWidth = chartContainer.offsetWidth * 0.92;

            if (meteo_index.includes("temperature")) {
                Array.from(elements).forEach(function (element) {
                    let [year, month] = element.id.split('-');

                    let spec = build_temperature_spec(year, month, meteo_index, containerWidth);

                    draw_spec(element, spec);
                });
            }
            else if (meteo_index == "precipitation") {
                let spec = null;

                Array.from(elements).forEach(function (element) {
                    if (time_frequency == "monthly") {
                        spec = build_monthly_precipitation_spec(meteo_index, element.id, containerWidth, compare_with_ref);
                    }
                    else {
                        let [year, month] = element.id.split('-');
                        spec = build_daily_precipitation_spec(meteo_index, year, month, containerWidth);
                    }

                    draw_spec(element, spec);
                });
            } else if (meteo_index == "pdsi") {

                Array.from(elements).forEach(function (element) {
                    let spec = build_pdsi_spec(meteo_index, element.id, containerWidth);

                    draw_spec(element, spec);
                });
            }
        }
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

        if (document.getElementById('viz_type').value == "chart") {
            if (document.getElementById('meteo_index').value == "precipitation") {
                if (document.getElementById("time_frequency").value == "monthly")
                    document.getElementById("chk_precipitation_ref_period_div").classList.remove("hidden");
                else
                    document.getElementById("chk_precipitation_ref_period_div").classList.add("hidden");
            }
            else {
                document.getElementById("chk_precipitation_ref_period_div").classList.add("hidden");
            }
        }
        else {
            document.getElementById("chk_precipitation_ref_period_div").classList.add("hidden");
        }
    });

    document.getElementById('meteo_index').addEventListener("change", e => {
        if (document.getElementById('viz_type').value == "chart") {
            if (document.getElementById('meteo_index').value == "precipitation") {
                if (document.getElementById("time_frequency").value == "monthly")
                    document.getElementById("chk_precipitation_ref_period_div").classList.remove("hidden");
                else
                    document.getElementById("chk_precipitation_ref_period_div").classList.add("hidden");
            }
            else {
                document.getElementById("chk_precipitation_ref_period_div").classList.add("hidden");
            }

            if (document.getElementById('meteo_index').value != "precipitation") {
                document.getElementById("viz_mode_div").classList.remove("hidden");
                document.getElementById("chk_correlate_div").classList.remove("hidden");
            }
        }
        else {
            document.getElementById("chk_precipitation_ref_period_div").classList.add("hidden");
        }

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

        if (document.getElementById('viz_type').value == "chart") {
            if (document.getElementById('meteo_index').value == "precipitation") {
                if (document.getElementById("time_frequency").value == "monthly")
                    document.getElementById("chk_precipitation_ref_period_div").classList.remove("hidden");
                else
                    document.getElementById("chk_precipitation_ref_period_div").classList.add("hidden");
            }
            else {
                document.getElementById("chk_precipitation_ref_period_div").classList.add("hidden");
            }
        }
        else {
            document.getElementById("chk_precipitation_ref_period_div").classList.add("hidden");
        }

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

    (document.querySelectorAll('.notification .delete') || []).forEach(($delete) => {
        const $notification = $delete.parentNode;

        $delete.addEventListener('click', () => {
            $notification.parentNode.removeChild($notification);
        });
    });
}