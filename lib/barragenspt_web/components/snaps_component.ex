defmodule SnapsComponent do
  use Phoenix.LiveComponent
  alias BarragensptWeb.Router.Helpers, as: Routes
  alias Barragenspt.Hydrometrics.Basins

  def update(_, socket) do
    get_data_for_all_basins()

    {:ok, content} = File.read("#{File.cwd!()}/priv/static/geojson/pt_basins.json")

    basins =
      []
      |> Barragenspt.Hydrometrics.Basins.summary_stats()
      |> Enum.map(fn {basin_id, name, current_storage, value} ->
        %{
          id: basin_id,
          replacement_key: "PCT_#{basin_id}",
          current_storage: current_storage |> Decimal.to_float(),
          average_historic_value: value |> Decimal.to_float()
        }
      end)

    replaced_json =
      Enum.reduce(basins, content, fn r, acc ->
        String.replace(
          acc,
          r.replacement_key,
          "#{r.current_storage / 100}, \"percent_historic\": #{r.average_historic_value / 100}, \"basin_id\": #{r.id}"
        )
      end)

    File.write("#{File.cwd!()}/priv/static/geojson/pt_basins_with_values.json", replaced_json)

    _data_url =
      "https://gist.githubusercontent.com/ricardoccpaiva/bdb5a0db0836988aab98c330accf1d71/raw/374d854284e4bdf074405db2714db53e3918eec1/gistfile1.txt"

    spec =
      VegaLite.new(width: :container, height: :container)
      |> VegaLite.data_from_url("/geojson/pt_basins_with_values.json",
        format: %{type: "topojson", feature: "pt_basins"}
      )
      |> VegaLite.mark(:geoshape)
      |> VegaLite.encode(:color,
        field: "properties.percent",
        type: :quantitative,
        legend: [title: "% Armazenada", format: "%"]
      )
      |> VegaLite.encode(
        :tooltip,
        [
          [field: "properties.name", type: :nominal, title: "Name:"],
          [
            field: "properties.percent",
            type: :quantitative,
            title: "% Armazenada:",
            format: ".1%"
          ]
        ]
      )
      |> VegaLite.to_spec()

    spec_map_historic =
      VegaLite.new(width: :container, height: :container)
      |> VegaLite.data_from_url("/geojson/pt_basins_with_values.json",
        format: %{type: "topojson", feature: "pt_basins"}
      )
      |> VegaLite.mark(:geoshape)
      |> VegaLite.encode(:color,
        field: "properties.percent_historic",
        type: :quantitative,
        legend: [title: "% Armazenada", format: "%"]
      )
      |> VegaLite.encode(
        :tooltip,
        [
          [field: "properties.name", type: :nominal, title: "Name:"],
          [
            field: "properties.percent_historic",
            type: :quantitative,
            title: "% Armazenada:",
            format: ".1%"
          ]
        ]
      )
      |> VegaLite.to_spec()

    metrics =
      Barragenspt.Hydrometrics.Basins.monthly_stats_for_basin("12", [], 2)
      |> Enum.map(fn d ->
        %{Data: Calendar.strftime(d.date, "%b %d %Y"), "% Armazenamento": d.value, Tipo: d.basin}
      end)

    spec_2 =
      VegaLite.new(title: "Evolução temporal", width: :container, height: :container, padding: 5)
      |> VegaLite.data_from_values(metrics)
      |> VegaLite.encode_field(:x, "Data", type: :temporal)
      |> VegaLite.layers([
        VegaLite.new()
        |> VegaLite.layers([
          VegaLite.new()
          |> VegaLite.mark(:line, interpolate: :natural),
          VegaLite.new()
          |> VegaLite.mark(:point)
          |> VegaLite.transform(filter: [param: "hover", empty: false])
        ])
        |> VegaLite.encode_field(:y, "% Armazenamento", type: :quantitative, scale: %{zero: false})
        |> VegaLite.encode(:color, field: "Tipo", type: :nominal),
        VegaLite.new()
        |> VegaLite.transform(pivot: "Tipo", value: "% Armazenamento", groupby: ["Data"])
        |> VegaLite.mark(:rule)
        |> VegaLite.encode(:opacity,
          condition: %{value: 0.3, param: "hover", empty: false},
          value: 0
        )
        |> VegaLite.encode(:tooltip, [
          [field: "Média", type: :quantitative],
          [field: "Observado", type: :quantitative]
        ])
        |> VegaLite.param("hover",
          select: [
            type: :point,
            fields: ["Data"],
            nearest: true,
            on: :mouseover,
            clear: :mouseout
          ]
        )
      ])
      |> VegaLite.to_spec()

    # |> VegaLite.Export.to_json()
    # |> IO.inspect(label: "------>")

    socket =
      socket
      |> push_event("draw", %{"spec" => spec})
      |> push_event("draw_map_historic", %{"spec_map_historic" => spec_map_historic})
      |> push_event("draw_2", %{"spec" => spec_2})

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
    <div style="width:400px; height: 400px" id="map_historic" phx-hook="MapHistoric"/>
    <div style="width:400px; height: 400px" id="graph" phx-hook="Dashboard"/>
    <div style="width:400px; height: 400px" id="graph_ot" phx-hook="OverTime"/>
    </div>
    """
  end

  defp get_data_for_all_basins() do
    date = Date.utc_today()
    stats = Basins.monthly_stats_for_basins([], 2)

    stats |> IO.inspect(label: "----->")
    # basin_id, name, data1, data2
    # Calendar.strftime(date, "%b %Y") |> IO.inspect(label: "---------->")

    all_basins = Enum.map(Basins.all(), fn b -> %{id: b.id, name: b.name} end)

    all_dates =
      stats
      |> Enum.filter(fn sd -> sd.date.year == date.year end)
      |> Enum.uniq(fn sd -> Calendar.strftime(sd.date, "%b %Y") end)
      |> Enum.map(fn sd -> sd.date end)
      |> Enum.sort({:asc, Date})

    content =
      Enum.map(all_basins, fn %{id: id, name: name} ->
        Enum.map(all_dates, fn ad ->
          Map.get(
            Enum.find(stats, fn s -> s.basin_id == id && s.date == ad end) || %{},
            :value,
            0
          )
        end)
        |> Enum.map(&(&1 / 100))
        |> Enum.map(&Float.ceil(&1, 4))
        |> Enum.join(",")
        |> String.replace_prefix("", "#{id},#{name},")
      end)
      |> Enum.join("\r\n")
      |> String.replace_prefix(
        "",
        "basin_id,basin_name,#{all_dates |> Enum.map(&Calendar.strftime(&1, "%b %Y")) |> Enum.join(",")}\r\n"
      )

    path = "#{File.cwd!()}/priv/static/csv/pt_basins_values.csv"

    File.write!(path, content)
  end
end
