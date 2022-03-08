defmodule Barragenspt.Workers.FetchDamsInfo do
  use Oban.Worker, queue: :dams_info
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id} = _args}) do
    "resources/dams.csv"
    |> File.stream!()
    |> NimbleCSV.RFC4180.parse_stream()
    |> Stream.map(fn [basin_id, basin, code, name] ->
      code
      |> get_http_session_cookie()
      |> fetch_xls_payload()
      |> write_to_file()
      |> convert_to_csv()
      |> fetch_metadata()
      |> insert_dam(name, code, basin_id, basin)

      Logger.info("Inserting damn with id #{code}")
      :timer.sleep(250)
    end)
    |> Stream.run()

    :ok
  end

  defp insert_dam(meta, name, code, basin_id, basin) do
    Barragenspt.Repo.insert!(%Barragenspt.Hydrometrics.Dam{
      name: name,
      code: code,
      basin: basin,
      basin_id: basin_id,
      metadata: meta
    })
  end

  defp get_http_session_cookie(code) do
    {:ok, response} =
      HTTPoison.get(
        "https://snirh.apambiente.pt/index.php?idRef=MTE3Nw==&simbolo_redehidro=#{code}#"
      )

    {"Set-Cookie", cookie} =
      Enum.find(response.headers, fn {key, _} -> String.match?(key, ~r/\ASet-Cookie\z/i) end)

    cookie
  end

  defp fetch_xls_payload(cookie) do
    %HTTPoison.Response{body: body} =
      HTTPoison.get!(
        "https://snirh.apambiente.pt/snirh/_dadossintese/albufeirasinv/export.php",
        %{},
        hackney: [cookie: [cookie]]
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
    regex_variant_for_kv = ~r/^(?'title'.+),(?'value'.+)$/

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
