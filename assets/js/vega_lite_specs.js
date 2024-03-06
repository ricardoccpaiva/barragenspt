import vegaEmbed from 'vega-embed';
import {
    temperature_domain,
    temperature_range,
    pdsi_domain,
    pdsi_range,
    monthly_precipitation_domain,
    monthly_precipitation_range,
    daily_precipitation_domain,
    daily_precipitation_range
} from './vega_lite_spec_constants';

export function build_daily_precipitation_for_one_year_spec(year) {
    url = "meteo_data?meteo_index=precipitation" + "&year=" + year + "&month=-1&scale=absolute&grouped=true&format.csv";

    return {
        "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
        "data": {
            "url": url
        },
        "width": "container",
        "height": 50,
        "mark": "bar",
        "config": {
            "legend": { "title": null, "labelPadding": 0, "labelFontSize": 0, "symbolOpacity": 0 }
        },
        "encoding": {
            "x": {
                "field": "date", "type": "temporal",
                "axis": { "title": "", "labelAngle": -45 }
            },
            "y": {
                "title": "", "field": "value", "type": "quantitative", "axis": {
                    "labelAngle": -45
                }
            },
            "color": {
                "field": "index",
                "type": "nominal",
                "scale": {
                    "domain": daily_precipitation_domain,
                    "range": daily_precipitation_range
                },
            },
            "tooltip": [
                { "field": "date", "type": "ordinal", "title": "Dia", "timeUnit": "binnedutcyearmonthdate" },
                { "field": "value", "type": "quantitative", "title": "Precipitação (mm)", "format": ".2f" }
            ]
        },
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

export function build_monthly_precipitation_spec(meteo_index, year, width, scale) {
    url = "meteo_data?meteo_index=" + meteo_index + "&year=" + year + "&scale=" + scale + "&grouped=true&format.csv";

    var unit = scale == "absolute" ? "(mm)" : "(%)";

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
            "x": {
                "field": "date", "type": "ordinal", "timeUnit": "yearmonth",
                "axis": { "title": "", "labelAngle": -45, "format": "%b" }
            },
            "y": { "field": "value", "type": "quantitative", "axis": { "title": "" } },
            "color": {
                "field": "index",
                "type": "nominal",
                "scale": {
                    "domain": monthly_precipitation_domain,
                    "range": monthly_precipitation_range
                },
            },
            "tooltip": [
                { "field": "date", "type": "ordinal", "title": "Mês", "format": "%b", "timeUnit": "yearmonth" },
                { "field": "value", "type": "quantitative", "title": "Precipitação " + unit, "format": ".2f" }
            ]
        },
    }
}

export function build_daily_precipitation_spec(meteo_index, year, month, width, scale) {
    url = "meteo_data?meteo_index=" + meteo_index + "&year=" + year + "&month=" + month + "&scale=" + scale + "&grouped=true&format.csv";

    var unit = scale == "absolute" ? "(mm)" : "(%)";

    return {
        "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
        "data": {
            "url": url
        },
        "width": width,
        "height": 150,
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
                    "domain": daily_precipitation_domain,
                    "range": daily_precipitation_range
                },
            },
            "tooltip": [
                { "field": "date", "type": "ordinal", "title": "Dia", "timeUnit": "date" },
                { "field": "value", "type": "quantitative", "title": "Precipitação " + unit, "format": ".2f" }
            ]
        },
    }
}

export function draw_spec(element, spec) {
    vegaEmbed(element, spec, { actions: false })
        .then((result) => result.view)
        .catch((error) => console.error(error))
}
