defmodule Barragenspt.Repo.Migrations.CreateTemperatureDailyValues do
  use Ecto.Migration

  def change do
    create table(:temperature_daily_value) do
      add :svg_path_hash, :string
      add :color_hex, :string
      add :date, :date
      add :geographic_area_type, :string
      add :layer, :string

      timestamps()
    end
  end
end
