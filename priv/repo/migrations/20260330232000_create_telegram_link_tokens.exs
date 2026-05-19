defmodule Barragenspt.Repo.Migrations.CreateTelegramLinkTokens do
  use Ecto.Migration

  def change do
    create table(:telegram_link_tokens) do
      add :token, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :expires_at, :utc_datetime_usec, null: false
      add :used_at, :utc_datetime_usec
      add :chat_id, :string
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:telegram_link_tokens, [:token])
    create index(:telegram_link_tokens, [:user_id])
    create index(:telegram_link_tokens, [:status])
  end
end
