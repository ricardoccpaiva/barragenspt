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

export function build_daily_basin_storage_for_one_year_spec(year, width) {
    url = "meteo_data?meteo_index=basin_storage" + "&year=" + year + "&format.csv";

    return {
        "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
        "width": width,
        "height": 200,
        "encoding": {
            "x": {
                "field": "date", "type": "temporal",
                "timeUnit": "yearmonth",
                "axis": { "title": "Mês", "format": "%B" },
            }
        },
        "layer": [
            {
                "data": {
                    "url": url
                },
                "encoding": {
                    "color": {
                        "field": "basin",
                        "type": "nominal",
                        "legend": null
                    },
                    "y": {
                        "field": "value",
                        "scale": { "domain": [0, 100] },
                        "type": "quantitative",
                        "axis": { "title": "% Armazenamento" },
                    }
                },
                "layer": [
                    { "mark": { "interpolate": "natural", "type": "line" } },
                    {
                        "mark": "point",
                        "transform": [
                            { "filter": { "empty": false, "param": "hover" } }
                        ]
                    }
                ]
            },
            {
                "data": {
                    "url": url
                },
                "encoding": {
                    "opacity": {
                        "condition": { "empty": false, "param": "hover", "value": 0.3 },
                        "value": 0
                    },
                    "tooltip": [
                        { "field": "date", "title": "Data", "type": "temporal" },
                        { "field": "Ave", "type": "quantitative" },
                        { "field": "Douro", "type": "quantitative" },
                        { "field": "Tejo", "type": "quantitative" },
                        { "field": "Sado", "type": "quantitative" },
                        { "field": "Guadiana", "type": "quantitative" },
                        { "field": "Mira", "type": "quantitative" },
                        { "field": "Lima", "type": "quantitative" },
                        { "field": "Mondego", "type": "quantitative" },
                        { "field": "Cávado/ribeiras Costeiras", "type": "quantitative" },
                        { "field": "Ribeiras Do Algarve", "type": "quantitative" },

                    ]
                },
                "mark": "rule",
                "params": [
                    {
                        "name": "hover",
                        "select": {
                            "clear": "mouseout",
                            "empty": false,
                            "fields": ["date"],
                            "nearest": true,
                            "on": "mouseover",
                            "type": "point"
                        }
                    }
                ],
                "transform": [
                    {
                        "groupby": ["date"],
                        "pivot": "basin",
                        "value": "value"
                    }
                ]
            }
        ]
    }
}

export function build_daily_precipitation_for_one_year_spec(year) {
    url = "meteo_data?meteo_index=precipitation" + "&year=" + year + "&format.csv";

    return {
        "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
        "data": {
            "url": url
        },
        "width": "container",
        "height": 50,
        "mark": "bar",
        "view": {
            "stroke": null
        },
        "config": {
            "axis": {
                "grid": false,
            },
            "legend": { "title": null, "labelPadding": 0, "labelFontSize": 0, "symbolOpacity": 0 }
        },
        "encoding": {
            "x": {
                "field": "date", "type": "temporal",
                "axis": { "title": "", "labelAngle": -15 }
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
        "view": {
            "stroke": null
        },
        "config": {
            "axis": {
                "grid": false,
            },
            "legend": { "title": null, "labelPadding": 0, "labelFontSize": 0, "symbolOpacity": 0 }
        },
        "encoding": {
            "x": {
                "field": "date", "type": "ordinal", "timeUnit": "date",
                "axis": { "title": "" }
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
            },
            "tooltip": [
                { "field": "month", "type": "ordinal", "title": "Mês", "format": "%b", "timeUnit": "yearmonth" },
                { "field": "value", "type": "quantitative", "title": "% território nacional", "format": ".2f" }
            ]
        }
    }
}

export function build_monthly_precipitation_spec(meteo_index, year, width, compare_with_ref) {
    url = "meteo_data?meteo_index=" + meteo_index + "&year=" + year + "&compare_with_ref=" + compare_with_ref + "&month=0&format.csv";

    var unit = "(mm)";

    return {
        "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
        "data": {
            "url": url
        },
        "transform": [
            { "calculate": "month(datum.date) + 1", "as": "month" }
        ],
        "width": width,
        "height": "container",
        "mark": "bar",
        "view": {
            "stroke": null
        },
        "config": {
            "axis": {
                "grid": false,
            },
            "legend": { "title": null, "labelPadding": 0, "labelFontSize": 0, "symbolOpacity": 0 }
        },
        "encoding": {
            "x": {
                "field": "date", "type": "ordinal", "timeUnit": "yearmonth",
                "axis": { "title": "", "labelAngle": 0, "format": "%b" }
            },
            "xOffset": { "field": "type" },
            "color": {
                "field": "index",
                "type": "nominal",
                "title": "",
                "scale": {
                    "domain": monthly_precipitation_domain,
                    "range": monthly_precipitation_range
                },
            },
            "y": { "field": "value", "type": "quantitative", "axis": { "title": "" } },
            "tooltip": [
                { "field": "date", "type": "ordinal", "title": "Mês", "format": "%b", "timeUnit": "yearmonth" },
                { "field": "value", "type": "quantitative", "title": "Precipitação " + unit, "format": ".2f" }
            ]
        },
    }
}

export function build_daily_precipitation_spec(meteo_index, year, month, width) {
    url = "meteo_data?meteo_index=" + meteo_index + "&year=" + year + "&month=" + month + "&format.csv";

    var unit = "(mm)";
    return {
        "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
        "data": {
            "url": url
        },
        "width": width,
        "height": "container",
        "mark": "bar",
        "view": {
            "stroke": null
        },
        "config": {
            "axis": {
                "grid": false,
            },
            "legend": { "title": null, "labelPadding": 0, "labelFontSize": 0, "symbolOpacity": 0 }
        },
        "encoding": {
            "x": {
                "field": "date", "type": "ordinal", "timeUnit": "date",
                "axis": { "title": "", "labelAngle": 0 }
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
