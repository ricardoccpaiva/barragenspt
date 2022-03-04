defmodule Barragenspt.Repo.Migrations.DropViews do
  use Ecto.Migration

  def up do
    execute "DROP VIEW basin_storage;"
  end
end
