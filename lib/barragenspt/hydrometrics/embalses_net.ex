defmodule Barragenspt.Hydrometrics.EmbalsesNet do
  use Nebulex.Caching
  alias Barragenspt.Cache
  alias Barragenspt.Mappers.Colors

  @decorate cacheable(cache: Cache, key: "spain_basins", ttl: :timer.hours(1))
  def basins_info() do
    tbl =
      Barragenspt.Services.EmbalsesNet.basins_info()
      |> Floki.parse_document!()
      |> Floki.find(".Tabla")

    [
      {"table",
       [
         {"border", "0"},
         {"align", "center"},
         {"cellpadding", "0"},
         {"cellspacing", "0"},
         {"class", "Tabla"}
       ], [{"tbody", [], tbl_content}]}
    ] = tbl

    [_header | rows] = tbl_content

    Enum.map(rows, fn row -> parse_row(row) end)
  end

  def basin_info(id) do
    basins = basins_info()

    Enum.find(basins, fn b -> b.id == id end)
  end

  defp parse_row(row) do
    mappings = [
      %{name: "Miño-Sil", resource_name: "mino_sil"},
      %{name: "Cataluña Interna", resource_name: "cataluna_interna"},
      %{name: "Tinto, Odiel y Piedras", resource_name: "tinto_odiel_piedras"},
      %{name: "Júcar", resource_name: "jucar"},
      %{name: "Guadalete-Barbate", resource_name: "guadalete_barbete"},
      %{name: "Med. Andaluza", resource_name: "andaluzia"}
    ]

    {"tr", [{"class", "ResultadoCampo"}],
     [
       {"td", [{"align", "center"}],
        [
          {"a",
           [
             {"href", _url},
             {"title", _display_name}
           ], [name]}
        ]},
       {"td", [{"align", "center"}], [_capacity]},
       {"td", [{"align", "right"}], [_current]},
       {"td", [{"align", "center"}], [current_pct]},
       {"td", [{"align", "right"}], [_variation]},
       {"td", [{"align", "center"}], [{"span", [{"class", ""}], [_variation_pct]}]}
     ]} = row

    current_pct_fixed =
      current_pct
      |> String.replace("(", "")
      |> String.replace(")", "")
      |> String.replace("%", "")

    name =
      case Enum.find(mappings, fn m -> m[:name] == name end) do
        nil -> name
        mapping -> mapping[:resource_name]
      end

    %{
      id: "#{XXHash.xxh32(name)}",
      basin_name: name,
      current_pct: current_pct_fixed,
      capacity_color:
        current_pct_fixed
        |> Decimal.parse()
        |> then(fn {dc, _} -> dc end)
        |> Decimal.to_float()
        |> Colors.lookup_capacity()
    }
  end
end
