defmodule BarragensptWeb.ReportsController do
  use BarragensptWeb, :controller

  def index(conn, _params) do
    redirect(conn, to: "/v2")
  end
end
