defmodule Barragenspt.ApiUsage.ApiTokenUsageBucket do
  @moduledoc false
  use Ecto.Schema

  schema "api_token_usage_buckets" do
    field :bucket_start, :utc_datetime_usec
    field :request_count, :integer

    belongs_to :user, Barragenspt.Accounts.User
    belongs_to :user_api_token, Barragenspt.Accounts.UserApiToken, foreign_key: :user_api_token_id

    timestamps(type: :utc_datetime_usec)
  end
end
