defmodule Barragenspt.Workers.DataPointsUpdate do
  use Oban.Worker, queue: :data_points_update
  import Ecto.Query
  require Logger

  @impl Oban.Worker
  def perform(_args) do
    # 354895424 - Cota da Albufeira na última hora
    # 1629599726 - Cota da Albufeira
    # 354895398 - Volume armazenado na última hora (dam3)
    # 1629599798 - Volume armazenado
    data_params = [
      {1_629_599_798, "volume"},
      {354_895_398, "volume_last_hour"},
      {304_545_050, "volume_last_day_month"}
    ]

    current_date = Timex.now()
    {:ok, end_date_str} = Timex.format(current_date, "{D}/{M}/{YYYY}")

    {:ok, start_date_str} =
      current_date |> Timex.shift(months: -1) |> Timex.format("{D}/{M}/{YYYY}")

    # data_params = [{354_895_398, "volume_last_hour"}]
    # data_params = [{1_629_599_798, "volume"}]

    from(d in Barragenspt.Hydrometrics.Dam, where: not is_nil(d.metadata))
    |> Barragenspt.Repo.all()
    |> Enum.map(fn dam ->
      try do
        {max_value, ""} = Integer.parse(dam.metadata["Albufeira"]["Capacidade total (dam3)"])

        Enum.map(data_params, fn {param_id, param_name} ->
          Barragenspt.Workers.FetchDamParameters.new(%{
            "id" => :rand.uniform(999_999_999),
            "dam_code" => dam.code,
            "basin_id" => dam.basin_id,
            "site_id" => dam.site_id,
            "parameter_id" => param_id,
            "parameter_name" => param_name,
            "start_date" => start_date_str,
            "end_date" => end_date_str,
            "max_value" => max_value
          })
        end)
      rescue
        _ -> []
      end
    end)
    |> List.flatten()
    |> Enum.reject(fn row -> row == [] end)
    |> Oban.insert_all()

    :ok
  end
end
