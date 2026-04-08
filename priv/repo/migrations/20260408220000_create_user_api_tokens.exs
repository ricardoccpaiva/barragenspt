defmodule Barragenspt.Repo.Migrations.CreateUserApiTokens do
  use Ecto.Migration

  def change do
    create table(:user_api_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token_digest, :binary, null: false
      add :token_prefix, :string, null: false
      add :scopes, {:array, :string}, null: false, default: []

      add :revoked_at, :utc_datetime_usec

      timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime_usec)
    end

    create index(:user_api_tokens, [:user_id])

    create index(:user_api_tokens, [:user_id],
             where: "revoked_at IS NULL",
             name: :user_api_tokens_user_id_active
           )
  end
end
