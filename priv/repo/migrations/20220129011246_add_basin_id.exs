defmodule Barragenspt.Repo.Migrations.AddBasinId do
  use Ecto.Migration

  def change do
    alter table(:dam) do
      add :basin_id, :integer
    end
  end
end
