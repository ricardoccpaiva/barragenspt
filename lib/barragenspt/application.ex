defmodule Barragenspt.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    OpentelemetryPhoenix.setup()
    OpentelemetryEcto.setup([:barragenspt, :repo])
    OpentelemetryOban.setup()
    OpentelemetryLiveView.setup()
    OpentelemetryLoggerMetadata.setup()

    children = [
      Barragenspt.PromEx,
      # Start the Ecto repository
      Barragenspt.Repo,
      # Start the Telemetry supervisor
      BarragensptWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Barragenspt.PubSub},
      # Start the Endpoint (http/https)
      BarragensptWeb.Endpoint,
      {Oban, oban_config()},
      Barragenspt.Cache,
      Barragenspt.MeteoDataCache
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Barragenspt.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BarragensptWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # Conditionally disable queues or plugins here.
  defp oban_config do
    Application.fetch_env!(:barragenspt, Oban)
  end
end
