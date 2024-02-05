defmodule Barragenspt.Repo.Migrations.CreateMunicipalities do
  use Ecto.Migration

  def change do
    create table(:svg_area) do
      add :name, :string
      add :svg_path, :text
      add :svg_path_hash, :string
      add :area, :decimal
      add :geographic_area_type, :string

      timestamps()
    end
  end
end
