defmodule Barragenspt.Workers.BuildBasinMonthlyStorageSvgs do
  use Oban.Worker, queue: :dams_info
  require Logger
  alias Barragenspt.Hydrometrics.Basins
  alias Barragenspt.Services.R2

  @impl Oban.Worker
  def perform(_args) do
    basin_ids = [
      "1551779250",
      "107",
      "1551779242",
      "12",
      "47",
      "17",
      "138",
      "38",
      "23",
      "68",
      "992",
      "8"
    ]

    basins_svg_template =
      "resources/svg/pt_basins_template.svg"
      |> Path.expand()
      |> File.read!()

    all_basins_info_grouped_by_date =
      basin_ids
      |> Enum.map(fn bid -> Basins.monthly_stats_for_basin(bid, [], 60) end)
      |> List.flatten()
      |> Enum.group_by(fn b -> b.date end)

    all_dates = Map.keys(all_basins_info_grouped_by_date)

    Enum.each(all_dates, fn d ->
      all_basins_info_grouped_by_date
      |> Map.get(d)
      |> build_svg(d, basins_svg_template)
    end)

    :ok
  end

  defp build_svg(info, date, template) do
    templated_svg =
      info
      |> Enum.reject(fn i -> i.basin_id == "Média" end)
      |> Enum.map(fn i ->
        %{
          from: "FILL_BASIN_#{i.basin_id}",
          to: Barragenspt.Mappers.Colors.lookup_capacity(i.value)
        }
      end)
      |> Enum.reduce(template, fn %{from: from, to: to}, acc ->
        String.replace(acc, from, to)
      end)

    {:ok, path} = Briefly.create(directory: true)

    file_path = Path.join(path, "#{UUID.uuid4()}.svg")

    :ok = File.write!(file_path, templated_svg)

    R2.upload(
      file_path,
      "/basin_storage/svg/monthly/#{date.year}_#{date.month}.svg"
    )
  end
end
