defmodule Barragenspt.Repo.Migrations.AddDeletedAtToUserApiTokens do
  use Ecto.Migration

  def change do
    alter table(:user_api_tokens) do
      add :deleted_at, :utc_datetime_usec
    end

    create index(:user_api_tokens, [:user_id, :deleted_at])
  end
end
