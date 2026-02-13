defmodule Barragenspt.Services.RealtimeDataExtractor do
  require Logger
  import Ecto.Query
  alias Barragenspt.Models.Hydrometrics.{Dam, DataPointRealtime}
  alias Barragenspt.Repo

  @base_url "https://infoagua.apambiente.pt/pt/cheias/cheia-detalhe/"
  @params_mapping [
    {2, "caudal_efluente"},
    {6, "caudal_afluente"},
    {3, "cota"},
    {7, "volume_armazenado"}
  ]

  def fetch(site_id) do
    case get_raw_html_content(site_id) do
      {:ok, body} ->
        body
        |> extract_station_parameters(site_id)
        |> prep(site_id)
        |> store(site_id)

      {:error, reason} ->
        Logger.error(
          "RealtimeDataExtractor: error fetching data for site_id=#{site_id}: #{inspect(reason)}"
        )
    end
  end

  defp get_raw_html_content(site_id) do
    url = @base_url <> site_id
    client = Tesla.client([])

    case Tesla.get(client, url) do
      {:ok, %Tesla.Env{body: body}} when is_binary(body) ->
        Logger.info("RealtimeDataExtractor: fetched raw html content for site_id=#{site_id}")
        {:ok, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def extract_station_parameters(body, site_id) when is_binary(body) do
    script_content =
      body
      |> Floki.parse_document!()
      |> Floki.find("script")
      |> Enum.filter(fn
        {"script", _, [content]} -> String.contains?(content, "DATA_StationParameters")
        _ -> false
      end)
      |> Enum.at(0)

    case script_content do
      {"script", _, [content]} ->
        regex = ~r/var DATA_StationParameters\s*=\s*(\[.*?\])\s*var/s
        [_, json] = Regex.run(regex, content)
        data = Jason.decode!(json)

        Logger.info(
          "RealtimeDataExtractor: extracted station parameters for site_id=#{site_id} with #{length(data)} data points"
        )

        data

      _ ->
        []
    end
  end

  def prep(data, site_id) when is_list(data) do
    dams =
      Repo.one(
        from d in Dam,
          where: d.site_id == ^site_id,
          select: %{basin_id: d.basin_id, code: d.code}
      )

    case dams do
      nil ->
        Logger.warning("RealtimeDataExtractor: no dam found for site_id=#{site_id}")
        nil

      %{basin_id: basin_id, code: dam_code} ->
        rows = build_rows(data, site_id, to_string(basin_id), dam_code)
        Logger.info("RealtimeDataExtractor: built #{length(rows)} rows for site_id=#{site_id}")

        rows
    end
  end

  defp build_rows(params_list, site_id, basin_id, dam_code) do
    mapping = Map.new(@params_mapping)
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    for param <- params_list,
        param_id = Map.get(param, "id"),
        param_name = mapping[param_id],
        param_name != nil,
        value_entry <- Map.get(param, "values", []),
        moment = value_entry["moment"],
        value = value_entry["value"],
        colected_at = parse_moment(moment),
        colected_at != nil do
      value_decimal =
        case value do
          x when is_integer(x) -> Decimal.new(x)
          x when is_float(x) -> Decimal.from_float(x)
        end

      %{
        site_id: site_id,
        basin_id: basin_id,
        dam_code: dam_code,
        param_id: to_string(param_id),
        param_name: param_name,
        value: value_decimal,
        colected_at: colected_at,
        inserted_at: now,
        updated_at: now
      }
    end
  end

  defp store(rows, site_id) when is_list(rows) do
    {row_count, _} = Repo.insert_all(DataPointRealtime, rows)
    Logger.info("RealtimeDataExtractor: stored #{row_count} rows for site_id=#{site_id}")

    row_count
  end

  defp store([], _site_id), do: 0

  defp parse_moment(moment) when is_binary(moment) do
    # "2026-02-13 13:00:00" -> "2026-02-13T13:00:00" for ISO8601
    iso = String.replace(moment, " ", "T")

    case NaiveDateTime.from_iso8601(iso) do
      {:ok, dt} -> dt
      _ -> nil
    end
  end

  defp parse_moment(_), do: nil
end
