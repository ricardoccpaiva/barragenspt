defmodule Barragenspt.Repo.Migrations.AddUniqueIndexUserApiTokensTokenDigest do
  use Ecto.Migration

  def change do
    create unique_index(:user_api_tokens, [:token_digest], name: :user_api_tokens_token_digest_unique)
  end
end
