defmodule BarragensptWeb.SnapshotController do
  use BarragensptWeb, :controller

  alias Barragenspt.BarragensptWeb
  alias Barragenspt.BarragensptWeb.Snapshot

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
