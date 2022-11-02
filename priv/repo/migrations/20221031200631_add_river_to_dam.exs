defmodule Barragenspt.Repo.Migrations.AddRiverToDam do
  use Ecto.Migration

  def change do
    alter table(:dam) do
      add :river, :string
    end
  end
end
