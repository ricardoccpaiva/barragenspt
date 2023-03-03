defmodule Barragenspt.Workers.MapRiverToDam do
  import Ecto.Query
  use Oban.Worker, queue: :dams_info
  require Logger

  @impl Oban.Worker
  def perform(_args) do
    "resources/rivers_mapping.csv"
    |> File.stream!()
    |> NimbleCSV.RFC4180.parse_stream()
    |> Stream.map(fn [basin_id, basin, code, meta, rio] ->
      search_and_update(basin_id, basin, code, meta, rio)
    end)
    |> Stream.run()

    :ok
  end

  defp search_and_update(basin_id, basin, code, meta, rio) do
    if(rio != "") do
      query = from(d in Barragenspt.Hydrometrics.Dam, where: like(d.code, ^code))
      dam = Barragenspt.Repo.one(query)

      if(dam != nil) do
        dam = Ecto.Changeset.change(dam, river: rio)

        Barragenspt.Repo.update!(dam)
      end
    end
  end
end
