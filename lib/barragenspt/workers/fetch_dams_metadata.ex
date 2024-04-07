defmodule Barragenspt.Workers.FetchDamsMetadata do
  @timeout 25000

  import Ecto.Query
  use Oban.Worker, queue: :dams_info
  require Logger
  alias Barragenspt.Repo, as: Repo

  def spawn_workers do
    Barragenspt.Hydrometrics.Dam
    |> from()
    |> Repo.all()
    |> Enum.map(fn dam ->
      Barragenspt.Workers.FetchDamsMetadata.new(%{
        "id" => :rand.uniform(999_999_999),
        "dam_id" => dam.id,
        "dam_code" => dam.code,
        "albuf_id" => dam.albuf_id
      })
    end)
    |> List.flatten()
    |> OpentelemetryOban.insert_all()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"id" => _job_id, "dam_id" => id, "dam_code" => code, "albuf_id" => albuf_id}
      }) do
    %{cookie: cookie, body: body} = get_http_session_cookie(code)

    %{cookie: alternative_cookie, body: alternative_body} =
      get_alternative_http_session_cookie(albuf_id)

    final_cookie =
      if(String.contains?(body, "td_detalhe_detalhe")) do
        cookie
      else
        if(String.contains?(alternative_body, "td_detalhe_detalhe")) do
          node =
            alternative_body
            |> Floki.parse_document!()
            |> Floki.find(".tbl_detalhes")
            |> Enum.at(0)

          try do
            {"table",
             [
               {"width", "100%"},
               {"border", "0"},
               {"cellspacing", "2"},
               {"cellpadding", "2"},
               {"class", "tbl_detalhes"}
             ],
             [
               {"tr", [], [{"th", [], ["Nome "]}, {"td", [], [" "]}]} | _rest
             ]} = node

            nil
          rescue
            MatchError -> alternative_cookie
          end
        else
          nil
        end
      end

    if final_cookie != nil do
      final_cookie
      |> fetch_xls_payload()
      |> write_to_file()
      |> convert_to_csv()
      |> fetch_metadata()
      |> update_dam(id)

      Logger.info("Updating metadata for dam with code #{code}")
    else
      dam = Repo.get(Barragenspt.Hydrometrics.Dam, id)
      Repo.delete!(dam)
    end

    :ok
  end

  defp update_dam(meta, id) do
    dam = Repo.get(Barragenspt.Hydrometrics.Dam, id)
    dam = Ecto.Changeset.change(dam, metadata: meta)

    Repo.update!(dam)
  end

  defp get_http_session_cookie(code) do
    options = [recv_timeout: @timeout, timeout: @timeout]

    {:ok, response} =
      HTTPoison.get(
        "https://snirh.apambiente.pt/index.php?idRef=MTE3Nw==&simbolo_redehidro=#{code}#",
        [],
        options
      )

    {"Set-Cookie", cookie} =
      Enum.find(response.headers, fn {key, _} -> String.match?(key, ~r/\ASet-Cookie\z/i) end)

    %{cookie: cookie, body: response.body}
  end

  defp get_alternative_http_session_cookie(code) do
    options = [recv_timeout: @timeout, timeout: @timeout]

    {:ok, response} =
      HTTPoison.get(
        "https://snirh.apambiente.pt/index.php?idMain=1&idItem=7&albufcode=#{code}",
        [],
        options
      )

    {"Set-Cookie", cookie} =
      Enum.find(response.headers, fn {key, _} -> String.match?(key, ~r/\ASet-Cookie\z/i) end)

    %{cookie: cookie, body: response.body}
  end

  defp fetch_xls_payload(cookie) do
    %HTTPoison.Response{body: body} =
      HTTPoison.get!(
        "https://snirh.apambiente.pt/snirh/_dadossintese/albufeirasinv/export.php",
        %{},
        hackney: [recv_timeout: @timeout, timeout: @timeout, cookie: [cookie]]
      )

    body
  end

  defp write_to_file(body) do
    {:ok, path} = Briefly.create(directory: true)

    file_path = Path.join(path, "#{UUID.uuid4()}.xls")
    :ok = File.write!(file_path, body)

    file_path
  end

  defp convert_to_csv(filename) do
    {csv, 0} = System.cmd("in2csv", ["#{filename}"])

    csv
  end

  defp fetch_metadata(csv) do
    top_level_categories = [
      "Barragem,",
      "Identificação,",
      "Dados Técnicos,",
      "Orgãos de Descarga,",
      "Albufeira,",
      "Bacia Hidrográfica,",
      "Características do curso de água principal,",
      "Escoamento anual associado à probabilidade de não excedência (dam3),",
      "Precipitação anual associada à probabilidade de não excedência (mm),"
    ]

    regex = ~r/^(?'value'[^:]+)(?'comma',)$/
    regex_for_kv = ~r/^(?'title'.+):,(?'value'.+)$/
    regex_variant_for_kv = ~r/^(?'title'.*?),(?'value'.+)$/

    csv
    |> String.split("\n")
    |> Enum.drop(4)
    |> Enum.reduce(%{}, fn line, acc ->
      cond do
        String.match?(line, regex) && line in top_level_categories ->
          %{"value" => value} = Regex.named_captures(regex, line)

          set_acc_current_key(acc, value)

        String.match?(line, regex_for_kv) ->
          %{"title" => title, "value" => value} = Regex.named_captures(regex_for_kv, line)

          add_values_to_acc(acc, title, value)

        String.match?(line, regex_variant_for_kv) ->
          %{"title" => title, "value" => value} = Regex.named_captures(regex_variant_for_kv, line)

          add_values_to_acc(acc, title, value)

        true ->
          acc
      end
    end)
    |> Map.drop([:current_key])
  end

  defp add_values_to_acc(acc, title, value) do
    current_values = acc[acc[:current_key]]
    updated_values = Map.put(current_values, title, value)
    Map.put(acc, acc[:current_key], updated_values)
  end

  defp set_acc_current_key(acc, value) do
    acc
    |> Map.put(:current_key, value)
    |> Map.put(value, %{})
  end
end
