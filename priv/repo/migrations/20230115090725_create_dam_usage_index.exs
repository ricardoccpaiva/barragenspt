defmodule Barragenspt.Repo.Migrations.CreateDamUsageIndex do
  use Ecto.Migration

  def up do
    create index(:dam_usage, [:site_id, :usage_name])
  end

  def down do
    drop index(:dam_usage, [:site_id, :usage_name])
  end
end
