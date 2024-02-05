defmodule Barragenspt.Repo.Migrations.CreatePrecipitationMonthlyValues do
  use Ecto.Migration

  def change do
    create table(:precipitation_monthly_value) do
      add :svg_path_hash, :string
      add :color_hex, :string
      add :year, :integer
      add :month, :integer
      add :geographic_area_type, :string

      timestamps()
    end
  end
end
