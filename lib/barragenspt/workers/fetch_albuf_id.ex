defmodule Barragenspt.Workers.FetchAlbufIds do
  import Ecto.Query
  use Oban.Worker, queue: :dams_info
  require Logger

  @impl Oban.Worker
  def perform(_args) do
    "resources/albufs.csv"
    |> File.stream!()
    |> NimbleCSV.RFC4180.parse_stream()
    |> Stream.map(fn [albufcode, _lat, _lng, nome, rio] ->
      search_and_update(albufcode, nome, rio)
    end)
    |> Stream.run()

    :ok
  end

  defp search_and_update(albufcode, name, river) do
    uppercase_name = name |> String.downcase() |> Recase.to_title()
    like = "%#{uppercase_name}%"

    query = from(d in Barragenspt.Hydrometrics.Dam, where: like(d.name, ^like))
    how_many_dams = query |> Barragenspt.Repo.all() |> Enum.count()

    case how_many_dams do
      0 ->
        Logger.info("No dams found for #{name} - #{river}")

      1 ->
        dam = Barragenspt.Repo.one(query)

        dam = Ecto.Changeset.change(dam, albuf_id: albufcode)

        Barragenspt.Repo.update!(dam)

      _ ->
        Logger.info("More than 1 dam found for #{name} - #{river}")
    end
  end
end
