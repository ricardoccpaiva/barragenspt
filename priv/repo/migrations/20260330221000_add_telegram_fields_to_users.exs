defmodule Barragenspt.Repo.Migrations.AddTelegramFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :telegram_chat_id, :string
      add :telegram_enabled, :boolean, null: false, default: false
    end
  end
end
