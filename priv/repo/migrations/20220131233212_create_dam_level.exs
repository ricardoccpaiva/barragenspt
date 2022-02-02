defmodule Barragenspt.Repo.Migrations.CreateDamLevel do
  use Ecto.Migration

  def change do
    create table(:dam_level) do
      add :reference_period_type, :string
      add :reference_period, :date
      add :reference_value_type, :string
      add :reference_value, :decimal
      add :dam_id, references(:dam, on_delete: :nothing)

      timestamps()
    end

    create index(:dam_level, [:dam_id])
  end
end
