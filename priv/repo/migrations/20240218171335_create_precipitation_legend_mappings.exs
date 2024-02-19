defmodule Barragenspt.Repo.Migrations.CreatePrecipitationLegendMappings do
  use Ecto.Migration

  def change do
    create table(:precipitation_legend_mapping) do
      add :color_hex, :string
      add :color_xyz, :string
      add :mean_value, :decimal
    end
  end
end
