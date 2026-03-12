defmodule BarragensptWeb.Plugs.Health do
  @moduledoc """
  Health check plug for Coolify/Docker/Traefik.
  GET /health returns 200 if the app and database are reachable, 503 otherwise.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(%{method: "GET", path_info: ["health"]} = conn, _opts) do
    case Barragenspt.Repo.query("SELECT 1") do
      {:ok, _} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, "ok")
        |> halt()

      {:error, _} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(503, "unhealthy")
        |> halt()
    end
  rescue
    _ ->
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(503, "unhealthy")
      |> halt()
  end

  def call(conn, _opts), do: conn
end
