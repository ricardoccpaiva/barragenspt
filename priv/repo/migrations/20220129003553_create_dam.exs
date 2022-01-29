defmodule Barragenspt.Repo.Migrations.CreateDam do
  use Ecto.Migration

  def change do
    create table(:dam) do
      add :code, :string
      add :name, :string
      add :basin, :string
      add :metadata, :map

      timestamps()
    end
  end
end
