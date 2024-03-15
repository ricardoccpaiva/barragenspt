# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :barragenspt,
  ecto_repos: [Barragenspt.Repo]

# Configures the endpoint
config :barragenspt, BarragensptWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: BarragensptWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Barragenspt.PubSub,
  live_view: [signing_salt: "r91nm81s"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.0",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

{seconds, micro_seconds} = DateTime.to_gregorian_seconds(DateTime.utc_now())
unique_id = "#{seconds}_#{micro_seconds}"

config :barragenspt, Oban,
  repo: Barragenspt.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       {"0 5 * * *", Barragenspt.Workers.DataPointsUpdate,
        args: %{jcid: unique_id}, max_attempts: 50},
       {"@reboot", Barragenspt.Workers.DataPointsUpdate,
        args: %{jcid: unique_id}, max_attempts: 50},
       {"0 5 * * *", Barragenspt.Workers.MeteoDataCacher,
        args: %{spawn: "true"}, max_attempts: 50},
       {"@reboot", Barragenspt.Workers.MeteoDataCacher, args: %{spawn: "true"}, max_attempts: 50}
     ]}
  ],
  queues: [dams_info: 10, dam_levels: 10, stats_cacher: 2, data_points_update: 1]

config :barragenspt, :snirh,
  csv_data_url: "https://snirh.apambiente.pt/snirh/_dadosbase/site/paraCSV/dados_csv.php"

config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role]

config :ex_aws, :s3,
  scheme: "https://",
  host: "e5841afb091ae329ae85de35190a8e5d.r2.cloudflarestorage.com",
  port: 443

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
