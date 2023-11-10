import vegaEmbed from 'vega-embed'
const MapHistoric = {
  mounted() {
    this.handleEvent(`draw_map_historic`, ({ spec_map_historic }) =>
      vegaEmbed(this.el, spec_map_historic)
        .then((result) => result.view)
        .catch((error) => console.error(error)),
    )
  },
}

export default MapHistoric