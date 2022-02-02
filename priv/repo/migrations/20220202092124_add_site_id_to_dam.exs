defmodule Barragenspt.Repo.Migrations.AddSiteIdToDam do
  use Ecto.Migration

  def change do
    alter table(:dam) do
      add :site_id, :string
    end
  end
end
