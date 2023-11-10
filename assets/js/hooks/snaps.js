import vegaEmbed from 'vega-embed'
const Dashboard = {
  mounted() {
    this.handleEvent(`draw_2`, ({ spec }) =>
      vegaEmbed(this.el, spec)
        .then((result) => result.view)
        .catch((error) => console.error(error)),
    )
  },

}

export default Dashboard