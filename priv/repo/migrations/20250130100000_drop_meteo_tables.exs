defmodule Barragenspt.Repo.Migrations.DropMeteoTables do
  use Ecto.Migration

  def up do
    # View depends on svg_area, drop first
    execute "DROP VIEW IF EXISTS svg_area_totals;"

    drop table(:pdsi_value)
    drop table(:precipitation_daily_value)
    drop table(:precipitation_monthly_value)
    drop table(:svg_area)
    drop table(:temperature_daily_value)
  end

  def down do
    # Recreate tables (structure only - no data)
    create table(:svg_area) do
      add :name, :string
      add :svg_path, :text
      add :svg_path_hash, :string
      add :area, :decimal
      add :geographic_area_type, :string

      timestamps()
    end

    create table(:pdsi_value) do
      add :svg_path_hash, :string
      add :color_hex, :string
      add :year, :integer
      add :month, :integer
      add :geographic_area_type, :string

      timestamps()
    end

    create table(:precipitation_monthly_value) do
      add :svg_path_hash, :string
      add :color_hex, :string
      add :year, :integer
      add :month, :integer
      add :geographic_area_type, :string

      timestamps()
    end

    create table(:precipitation_daily_value) do
      add :svg_path_hash, :string
      add :color_hex, :string
      add :date, :date
      add :geographic_area_type, :string

      timestamps()
    end

    create table(:temperature_daily_value) do
      add :svg_path_hash, :string
      add :color_hex, :string
      add :date, :date
      add :geographic_area_type, :string
      add :layer, :string

      timestamps()
    end

    # Recreate view
    execute """
    CREATE VIEW svg_area_totals AS
      SELECT sum(area), geographic_area_type
      FROM svg_area
      GROUP BY geographic_area_type
    ;
    """
  end
end
