defmodule BarragensptWeb.Router do
  use BarragensptWeb, :router

  import BarragensptWeb.UserAuth
  import Oban.Web.Router
  import Plug.BasicAuth

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {BarragensptWeb.LayoutView, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:fetch_current_scope_for_user)
  end

  pipeline :authenticated do
    plug(:require_authenticated_user)
  end

  pipeline :private do
    plug :basic_auth,
      username: "paiva",
      password: "nodar"
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug OpenApiSpex.Plug.PutApiSpec, module: BarragensptWeb.ApiSpec
  end

  pipeline :api_protected do
    plug(BarragensptWeb.Plugs.ApiTokenAuth, required_scopes: ["basins"])
    plug(BarragensptWeb.Plugs.ApiUsage)
  end

  scope "/telegram", BarragensptWeb do
    pipe_through(:api)

    post("/webhook", TelegramWebhookController, :create)
  end

  scope "/api" do
    pipe_through(:api)
    get "/openapi", OpenApiSpex.Plug.RenderSpec, []
    get "/redoc", Redoc.Plug.RedocUI, spec_url: "/api/openapi"
  end

  scope "/api", BarragensptWeb do
    pipe_through([:api_protected])

    get("/basins", Api.BasinsController, :index)
    get("/basins/:id", Api.BasinsController, :show)
    get("/basins/:id/dams/:site_id", Api.BasinsController, :dam)
    get("/basins/:id/dams", Api.BasinsController, :dams)
    get("/dams/:id/info", Api.DamsController, :info)
    get("/dams/:id", Api.DamsController, :show)
    get("/data-points", Api.DataPointsController, :index)
    get("/data-points/params", Api.DataPointsController, :param_catalog)
  end

  scope "/oban", BarragensptWeb do
    pipe_through(:browser)
    pipe_through(:private)

    oban_dashboard("/")
  end

  scope "/", BarragensptWeb do
    pipe_through(:browser)

    live_session :default,
      on_mount: [{BarragensptWeb.UserAuth, :mount_current_scope}] do
      live("/", HomepageV2Live, :index)
      live("/basins/:basin_id", HomepageV2Live, :index)
      live("/basins/:basin_id/dams/:dam_id", HomepageV2Live, :index)
    end
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

      live_dashboard("/dev/dashboard", metrics: BarragensptWeb.Telemetry)
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

  ## Authenticated controllers (plug runs before action)

  scope "/", BarragensptWeb do
    pipe_through [:browser, :authenticated]

    get "/dashboard/data-points/export/csv", Dashboard.DataPointsExportController, :csv
    post "/users/update-password", UserSessionController, :update_password
  end

  ## Dashboard & account LiveViews: browser pipeline only — guests may open /dashboard;
  ## each tool enforces auth via `on_mount {UserAuth, :require_authenticated}`.

  scope "/", BarragensptWeb do
    pipe_through [:browser]

    live_session :authenticated,
      on_mount: [{BarragensptWeb.UserAuth, :mount_current_scope}] do
      live "/dashboard", DashboardLive, :index
      live "/dashboard/data-points", Dashboard.DataPointsLive, :index
      live "/dashboard/basin-report", Dashboard.BasinReportLive, :index
      live "/dashboard/api-tokens", Dashboard.ApiTokensLive, :index
      live "/dashboard/alerts", Dashboard.AlertsLive, :index
      live "/dashboard/alerts/new", Dashboard.AlertFormLive, :new
      live "/dashboard/alerts/:id/history", Dashboard.AlertHistoryLive, :show
      live "/dashboard/alerts/:id/edit", Dashboard.AlertFormLive, :edit

      if Mix.env() in [:dev, :test] do
        live "/dashboard/test/force-dam-value", Dashboard.TestDataPointsLive, :index
      end

      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end
  end

  scope "/", BarragensptWeb do
    pipe_through [:browser]

    get "/auth/:provider", UserOAuthController, :request
    get "/auth/:provider/callback", UserOAuthController, :callback

    live_session :current_user,
      on_mount: [{BarragensptWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
