defmodule BarragensptWeb.Plugs.ApiTokenAuth do
  @moduledoc false
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias Barragenspt.{Accounts, ApiTokenCache}

  def init(_opts), do: %{}

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> plain] ->
        plain = String.trim(plain)

        if plain == "" do
          unauthorized(conn, "Missing bearer token")
        else
          digest = :crypto.hash(:sha256, plain)

          case resolve_token(digest) do
            {:ok, payload} ->
              conn
              |> assign(:api_token_id, payload.id)
              |> assign(:api_user_id, payload.user_id)

            :error ->
              unauthorized(conn, "Invalid or revoked token")
          end
        end

      _ ->
        unauthorized(conn, "Missing or invalid Authorization header (expected Bearer token)")
    end
  end

  defp resolve_token(digest) do
    key = Accounts.api_token_cache_key(digest)

    case ApiTokenCache.get(key) do
      %{} = cached ->
        {:ok, cached}

      _ ->
        case Accounts.fetch_active_api_token_by_digest(digest) do
          {:ok, row} ->
            ttl =
              Application.get_env(:barragenspt, :api_token_cache_ttl, :timer.minutes(5))

            :ok = ApiTokenCache.put(key, row, ttl: ttl)
            {:ok, row}

          :error ->
            :error
        end
    end
  end

  defp unauthorized(conn, detail) do
    conn
    |> put_status(:unauthorized)
    |> json(%{errors: [%{title: "Unauthorized", detail: detail}]})
    |> halt()
  end
end
