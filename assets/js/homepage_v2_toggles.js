function getMap() {
    return window.map;
}

export function applyBasinsLayerActive(active) {
    var map = getMap();
    if (!map) return;
    var style = map.getStyle();
    if (!style || !style.layers) return;
    var opacity = active ? 0.7 : 0.1;
    style.layers.forEach(function (layer) {
        if (layer.type === 'fill' && layer.id.endsWith('_fill')) {
            map.setPaintProperty(layer.id, 'fill-opacity', opacity);
        }
    });
}

var DAMS_CIRCLE_COLOR_GRAY = '#94a3b8';

// Escala alinhada com app.css (.legend-0-20 … .legend-81-100); step = valor >= threshold
var CAPACITY_COLOR_STOPS = {
    default: '#ff675c',
    stops: [
        [21, '#ffc34a'],
        [41, '#ffe99c'],
        [51, '#c2faaa'],
        [61, '#a6d8ff'],
        [81, '#1c9dff']
    ]
};

function buildStepExpression(property, { default: defaultColor, stops }) {
    var exp = ['step', ['get', property], defaultColor];
    stops.forEach(function (s) { exp.push(s[0], s[1]); });
    return exp;
}

var DAMS_CIRCLE_COLOR_BY_CAPACITY = buildStepExpression('pct', CAPACITY_COLOR_STOPS);

export function applyDamsLayerActive(active) {
    var map = getMap();
    if (!map || !map.getLayer('dams-circles')) return;
    map.setPaintProperty('dams-circles', 'circle-color', active ? DAMS_CIRCLE_COLOR_BY_CAPACITY : DAMS_CIRCLE_COLOR_GRAY);
}

export var DAMS_CIRCLE_COLOR_GRAY_EXPORT = DAMS_CIRCLE_COLOR_GRAY;

export function navigateToSpainBasin(basinId) {
    const link = document.getElementById("basinDetailLink");
    const target = `/v2/basins/${basinId}?country=es`;
    if (link) {
        link.setAttribute("href", target);
        link.click();
        return;
    }
    window.location.href = target;
}

export const LayerToggleHooks = {
    BasinsLayerToggle: {
        mounted() {
            var el = this.el;
            if (!el._basinsListenerAdded) {
                el._basinsListenerAdded = true;
                el.addEventListener('change', function () {
                    applyBasinsLayerActive(el.checked);
                });
            }
            applyBasinsLayerActive(el.checked);
        }
    },

    DamsLayerToggle: {
        mounted() {
            var el = this.el;
            if (!el._damsListenerAdded) {
                el._damsListenerAdded = true;
                el.addEventListener('change', function () {
                    applyDamsLayerActive(el.checked);
                });
            }
            applyDamsLayerActive(el.checked);
        }
    },

    SpainLayerToggle: {
        mounted() {
            var el = this.el;
            el.addEventListener('change', function () {
                this.pushEvent('toggle_spain', { checked: el.checked });
            }.bind(this));
            if (el.checked) {
                this.pushEvent('toggle_spain', { checked: el.checked });
            }
        }
    }
};

window.spainBasins = [];

function registerSpainListeners() {
    window.addEventListener('phx:draw_spain_basins', function (e) {
        if (typeof topbar !== 'undefined') topbar.hide();
        var map = getMap();
        if (!map) return;
        var basins = e.detail.basins || [];
        window.spainBasins = basins;
        basins.forEach(function (item) {
            var sourceId = 'es_' + item.basin_name;
            var fillLayerId = sourceId + '_fill';
            var outlineLayerId = sourceId + '_outline';
            if (map.getSource(sourceId)) return;
            map.addSource(sourceId, { type: 'geojson', data: '/geojson/spain/' + item.basin_name + '.geojson' });
            map.addLayer({
                id: fillLayerId,
                type: 'fill',
                source: sourceId,
                layout: {},
                paint: {
                    'fill-color': item.capacity_color || '#94a3b8',
                    'fill-opacity': 0.6
                }
            });
            map.addLayer({
                id: outlineLayerId,
                type: 'line',
                source: sourceId,
                layout: {},
                paint: { 'line-color': '#000', 'line-width': 0.5 }
            });
            map.on('click', fillLayerId, function (ev) {
                var sid = ev.features[0].source;
                var basinName = sid.replace(/^es_/, '');
                var basin = window.spainBasins.find(function (b) { return b.basin_name === basinName; });
                if (basin) navigateToSpainBasin(basin.id);
            });
            map.on('mouseenter', fillLayerId, function () { map.getCanvas().style.cursor = 'pointer'; });
            map.on('mouseleave', fillLayerId, function () { map.getCanvas().style.cursor = ''; });
        });
        map.fitBounds([
            [-10.0186, 35.588],
            [3.8135, 43.9644]
        ]);
    });

    window.addEventListener('phx:remove_spain_basins', function (e) {
        if (typeof topbar !== 'undefined') topbar.hide();
        window.spainBasins = [];
        var map = getMap();
        if (!map) return;
        var style = map.getStyle();
        if (!style || !style.layers) return;
        var sourceIds = {};
        style.layers.forEach(function (layer) {
            if (layer.id.startsWith('es_')) {
                if (map.getLayer(layer.id)) map.removeLayer(layer.id);
                var sourceId = layer.id.replace(/_fill$/, '').replace(/_outline$/, '');
                if (layer.id !== sourceId) sourceIds[sourceId] = true;
            }
        });
        Object.keys(sourceIds).forEach(function (sid) {
            if (map.getSource(sid)) map.removeSource(sid);
        });
        map.fitBounds([
            [-9.708570, 36.682035],
            [-6.072327, 42.615949]
        ]);
    });
}

registerSpainListeners();
