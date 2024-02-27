import vegaEmbed from 'vega-embed';
import {
    temperature_domain,
    temperature_range,
    pdsi_domain,
    pdsi_range
} from './vega_lite_spec_constants';

export function build_precipitation_spec(id) {
    url = "meteo_data?meteo_index=precipitation&year=" + id + "&format=.csv";
    return {
        "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
        "data": { "url": url },
        "mark": "bar",
        "width": "container",
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
}

export function build_temperature_spec(year, month, meteo_index, width) {
    url = "meteo_data?meteo_index=" + meteo_index + "&year=" + year + "&month=" + month + "&format=.csv";

    return {
        "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
        "data": {
            "url": url
        },
        "transform": [
            { "calculate": "day(datum.date)", "as": "day_of_month" }
        ],
        "width": width,
        "autosize": "fit-y",
        "mark": "bar",
        "config": {
            "legend": { "title": null, "labelPadding": 0, "labelFontSize": 0, "symbolOpacity": 0 }
        },
        "encoding": {
            "x": {
                "field": "date", "type": "ordinal", "timeUnit": "date",
                "axis": { "title": "", "labelAngle": -45 }
            },
            "y": { "field": "value", "type": "quantitative", "axis": { "title": "" } },
            "color": {
                "field": "index",
                "type": "nominal",
                "scale": {
                    "domain": temperature_domain,
                    "range": temperature_range

                },
            }
        }
    }
}

export function build_pdsi_spec(meteo_index, year, width) {
    url = "meteo_data?meteo_index=" + meteo_index + "&year=" + year + "&format.csv";

    return {
        "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
        "data": {
            "url": url
        },
        "transform": [
            { "calculate": "month(datum.date) + 1", "as": "month" }
        ],
        "width": width,
        "height": 150,
        "mark": "bar",
        "config": {
            "legend": { "title": null, "labelPadding": 0, "labelFontSize": 0, "symbolOpacity": 0 }
        },
        "encoding": {
            "x": { "field": "month", "type": "ordinal", "axis": { "title": "", "labelAngle": 0 } },
            "y": { "field": "value", "type": "quantitative", "axis": { "title": "" } },
            "color": {
                "field": "index",
                "type": "nominal",
                "scale": {
                    "domain": pdsi_domain,
                    "range": pdsi_range
                },
            }
        }
    }
}

export function draw_spec(element, spec) {
    vegaEmbed(element, spec, { actions: false })
        .then((result) => result.view)
        .catch((error) => console.error(error))
}
