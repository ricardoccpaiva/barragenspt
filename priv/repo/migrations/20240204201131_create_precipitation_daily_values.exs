defmodule Barragenspt.Repo.Migrations.CreatePrecipitationDailyValues do
  use Ecto.Migration

  def change do
    create table(:precipitation_daily_value) do
      add :svg_path_hash, :string
      add :color_hex, :string
      add :date, :date
      add :geographic_area_type, :string

      timestamps()
    end
  end
end
