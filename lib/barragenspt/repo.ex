defmodule Barragenspt.Repo do
  use Ecto.Repo,
    otp_app: :barragenspt,
    adapter: Ecto.Adapters.Postgres
end
