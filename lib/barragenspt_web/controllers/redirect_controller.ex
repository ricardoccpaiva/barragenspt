defmodule BarragensptWeb.RedirectController do
  use BarragensptWeb, :controller

  def v2(conn, _params) do
    redirect(conn, to: "/")
  end
end
