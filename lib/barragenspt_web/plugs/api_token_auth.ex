defmodule BarragensptWeb.Plugs.ApiTokenAuth do
  @moduledoc false
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias Barragenspt.{Accounts, ApiTokenCache}

  def init(opts) do
    %{required_scopes: Keyword.get(opts, :required_scopes, [])}
  end

  def call(conn, %{required_scopes: required}) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> plain] ->
        plain = String.trim(plain)

        if plain == "" do
          unauthorized(conn, "Missing bearer token")
        else
          digest = :crypto.hash(:sha256, plain)

          case resolve_token(digest) do
            {:ok, payload} ->
              if scopes_cover?(payload.scopes, required) do
                conn
                |> assign(:api_token_id, payload.id)
                |> assign(:api_user_id, payload.user_id)
                |> assign(:api_token_scopes, payload.scopes)
              else
                forbidden(conn, "Token does not allow this resource")
              end

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

  defp scopes_cover?(token_scopes, required) do
    Enum.all?(required, &(&1 in token_scopes))
  end

  defp unauthorized(conn, detail) do
    conn
    |> put_status(:unauthorized)
    |> json(%{errors: [%{title: "Unauthorized", detail: detail}]})
    |> halt()
  end

  defp forbidden(conn, detail) do
    conn
    |> put_status(:forbidden)
    |> json(%{errors: [%{title: "Forbidden", detail: detail}]})
    |> halt()
  end
end
