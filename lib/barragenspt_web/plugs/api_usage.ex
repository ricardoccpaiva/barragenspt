defmodule BarragensptWeb.Plugs.ApiUsage do
  @moduledoc false

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = conn.assigns[:api_user_id]
    token_id = conn.assigns[:api_token_id]

    if is_integer(user_id) and is_integer(token_id) do
      Barragenspt.ApiUsage.increment(user_id, token_id)
    end

    conn
  end
end
