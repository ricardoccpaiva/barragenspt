defmodule Barragenspt.Repo.Migrations.CreateApiTokenUsageBuckets do
  use Ecto.Migration

  def change do
    create table(:api_token_usage_buckets) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :user_api_token_id, references(:user_api_tokens, on_delete: :delete_all), null: false
      add :bucket_start, :utc_datetime_usec, null: false
      add :request_count, :bigint, null: false, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:api_token_usage_buckets, [:user_id, :user_api_token_id, :bucket_start],
             name: :api_token_usage_buckets_user_token_bucket_unique
           )
  end
end
