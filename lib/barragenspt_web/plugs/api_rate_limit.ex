defmodule BarragensptWeb.Plugs.ApiRateLimit do
  @moduledoc false

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def init(opts), do: opts

  def call(conn, _opts) do
    if rate_limit_enabled?() do
      limit_conn(conn)
    else
      conn
    end
  end

  defp rate_limit_enabled? do
    Application.get_env(:barragenspt, Barragenspt.ApiRateLimit, [])
    |> Keyword.get(:enabled, true)
  end

  defp limit_conn(conn) do
    user_id = conn.assigns[:api_user_id]
    token_id = conn.assigns[:api_token_id]

    if is_integer(user_id) and is_integer(token_id) do
      key = {:api_token, user_id, token_id}

      case Barragenspt.ApiRateLimit.hit(key) do
        {:allow, _} ->
          conn

        {:deny, retry_after_ms} ->
          retry_after_s = max(1, div(retry_after_ms + 999, 1000))

          conn
          |> put_resp_header("retry-after", Integer.to_string(retry_after_s))
          |> put_status(:too_many_requests)
          |> json(%{
            errors: [
              %{
                title: "Too Many Requests",
                detail:
                  "Rate limit exceeded for this API token in the current window. Try again in about #{retry_after_s} second(s)."
              }
            ]
          })
          |> halt()
      end
    else
      conn
    end
  end
end
