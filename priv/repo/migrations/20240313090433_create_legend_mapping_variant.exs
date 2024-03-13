defmodule Barragenspt.Repo.Migrations.CreateLegendMappingVariant do
  use Ecto.Migration

  def change do
    alter table(:legend_mapping) do
      add :variant, :string
    end
  end
end
