import vegaEmbed from 'vega-embed'
const MetricsEvolution = {
  mounted() {
    this.handleEvent(`draw`, ({ spec }) =>
      vegaEmbed(this.el, spec, { actions: false })
        .then((result) => result.view)
        .catch((error) => console.error(error)),
    )
  },
}

export default MetricsEvolution