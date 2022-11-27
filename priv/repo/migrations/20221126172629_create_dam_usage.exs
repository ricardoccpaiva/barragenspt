defmodule Barragenspt.Repo.Migrations.CreateDamUsage do
  use Ecto.Migration

  def change do
    create table(:dam_usage) do
      add :site_id, :string
      add :usage_name, :string

      timestamps()
    end
  end
end
