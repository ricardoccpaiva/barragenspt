defmodule Barragenspt.Hydrometrics.Basins do
  import Ecto.Query

  def all() do
    query =
      from(p in Barragenspt.Hydrometrics.Dam,
        group_by: [p.basin_id, p.basin],
        select: %{basin: p.basin, id: p.basin_id}
      )

    Barragenspt.Repo.all(query)
  end

  def get(id) do
    query =
      from(p in Barragenspt.Hydrometrics.Dam,
        group_by: [p.basin_id, p.basin],
        where: p.basin_id == ^id,
        select: %{basin: p.basin, id: p.basin_id}
      )

    Barragenspt.Repo.one(query)
  end
end
