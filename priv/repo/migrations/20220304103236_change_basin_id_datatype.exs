defmodule Barragenspt.Repo.Migrations.ChangeBasinIdDatatype do
  use Ecto.Migration

  def up do
    alter table(:dam) do
      modify :basin_id, :string
    end
  end

  def down do
    alter table(:dam) do
      modify :basin_id, :integer
    end
  end
end
