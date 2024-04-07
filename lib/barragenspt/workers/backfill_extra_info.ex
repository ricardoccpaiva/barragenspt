defmodule Barragenspt.Workers.BackFillExtraDamInfo do
  import Ecto.Query
  use Oban.Worker, queue: :dams_info
  require Logger
  alias Barragenspt.Models.Hydrometrics.{DamUsage, Dam}
  alias Barragenspt.Repo, as: Repo

  @impl Oban.Worker
  def perform(_args) do
    from(_x in DamUsage) |> Barragenspt.Repo.delete_all()

    Dam
    |> from()
    |> Repo.all()
    |> Enum.map(fn dam ->
      usages = dam.metadata["Albufeira"]["Tipos de aproveitamento"]

      usages
      |> String.replace("\"", "")
      |> String.split(",")
      |> Enum.map(fn usage -> extract_usage(usage) end)
      |> build_and_insert_all(dam)

      try do
        {max_value, ""} = Integer.parse(dam.metadata["Albufeira"]["Capacidade total (dam3)"])

        query = from(d in Dam, where: like(d.code, ^dam.code))

        dam = Barragenspt.Repo.one(query)

        dam = Ecto.Changeset.change(dam, total_capacity: max_value)

        Barragenspt.Repo.update!(dam)
      rescue
        _ ->
          Logger.error("Failed to parse #{dam.name}")
      end
    end)

    :ok
  end

  defp build_and_insert_all(usage_names, dam) do
    usage_names
    |> Enum.map(fn usage_name -> build(usage_name, dam.site_id) end)
    |> Enum.each(fn usage -> Barragenspt.Repo.insert!(usage) end)
  end

  defp build(usage_name, site_id) do
    %DamUsage{
      site_id: site_id,
      usage_name: usage_name
    }
  end

  defp extract_usage(usage_name) do
    usage_name
    |> String.trim()
    |> String.replace(
      "Não existem usos associados à albufeira seleccionada.",
      "Indefinido"
    )
    |> extract_title()
    |> String.trim()
  end

  defp extract_title(usage_name) do
    regex = ~r/^(?'title'.*?)-(?'value'.+)$/

    if String.match?(usage_name, regex) do
      %{"title" => title, "value" => _value} = Regex.named_captures(regex, usage_name)

      title
    else
      usage_name
    end
  end
end
