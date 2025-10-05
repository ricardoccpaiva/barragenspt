defmodule BarragensptWeb.Router do
  use BarragensptWeb, :router
  import Oban.Web.Router
  import Plug.BasicAuth

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {BarragensptWeb.LayoutView, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :private do
    plug :basic_auth,
      username: System.get_env("OBAN_USERNAME"),
      password: System.get_env("OBAN_PASSWORD")
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/oban", BarragensptWeb do
    pipe_through(:browser)
    pipe_through(:private)

    oban_dashboard("/")
  end

  scope "/", BarragensptWeb do
    pipe_through(:browser)

    get("/reports", ReportsController, :index)
    get("/meteo_data", MeteoDataController, :index)

    live_session :default do
      live("/", HomepageLive, :index)
    end
  end

  # API scope
  scope "/api", BarragensptWeb do
    pipe_through :api

    get("/dams", DamController, :index)
    get("/basins", BasinController, :index)
  end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: BarragensptWeb.Telemetry)
    end
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through(:browser)

      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
