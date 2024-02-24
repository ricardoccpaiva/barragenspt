defmodule Barragenspt.Repo.Migrations.CreateSvgFolders do
  use Ecto.Migration

  def up do
    folders = [
      "priv/static/images/pdsi",
      "priv/static/images/precipitation",
      "priv/static/images/smi",
      "priv/static/images/temperature",
      "priv/static/images/basin_storage"
    ]

    sub_folders = ["daily", "monthly"]

    Enum.each(folders, fn f ->
      Enum.each(sub_folders, fn sf ->
        path = "#{f}/svg/#{sf}"

        if !File.exists?(path) do
          IO.puts("---> creating #{path}")

          path
          |> File.mkdir_p()
        end
      end)
    end)

    :ok
  end

  def down do
  end
end
