defmodule Barragenspt.Repo.Migrations.AddTotalCapacityToDam do
  use Ecto.Migration

  def change do
    alter table(:dam) do
      add :total_capacity, :integer
    end
  end
end
