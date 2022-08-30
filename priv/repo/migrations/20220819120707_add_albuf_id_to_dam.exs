defmodule Barragenspt.Repo.Migrations.AddAlbufIdToDam do
  use Ecto.Migration

  def change do
    alter table(:dam) do
      add :albuf_id, :string
    end
  end
end
