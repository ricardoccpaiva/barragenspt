defmodule Barragenspt.Repo.Migrations.CreateLegendMappings do
  use Ecto.Migration

  def change do
    create table(:legend_mapping) do
      add :meteo_index, :string
      add :color_hex, :string
      add :color_xyz, :string
      add :min_value, :decimal
      add :max_value, :decimal
    end
  end
end
