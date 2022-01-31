defmodule Barragenspt.Workers.FetchDamsInfo do
  use Oban.Worker, queue: :dams_info
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id} = _args}) do
    File.mkdir("resources/tmp")
    File.mkdir("resources/tmp/job_#{id}")

    "resources/dams.csv"
    |> File.stream!()
    |> NimbleCSV.RFC4180.parse_stream()
    |> Stream.map(fn [basin_id, basin, code, name] ->
      code
      |> get_http_session_cookie()
      |> fetch_xls_payload()
      |> write_to_file(code, id)
      |> convert_to_csv()
      |> fetch_metadata()
      |> insert_dam(name, code, basin_id, basin)

      Logger.info("Inserting damn with id #{code}")
      :timer.sleep(250)
    end)
    |> Stream.run()

    File.rm_rf!("resources/tmp/job_#{id}")

    :ok
  end

  defp insert_dam(meta, name, code, basin_id, basin) do
    Barragenspt.Repo.insert!(%Barragenspt.Hydrometrics.Dam{
      name: name,
      code: code,
      basin: basin,
      basin_id: String.to_integer(basin_id),
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

  defp write_to_file(body, dam_code, job_id) do
    filename = "resources/tmp/job_#{job_id}/#{String.replace(dam_code, "/", "_")}"

    :ok = File.write!("#{filename}.xls", body)

    filename
  end

  defp convert_to_csv(filename) do
    {csv, 0} = System.cmd("in2csv", ["#{filename}.xls"])

    csv
  end

  defp fetch_metadata(csv) do
    regex = ~r/^(?'value'[^:]+)(?'comma',)$/
    regex_for_kv = ~r/^(?'title'.+):,(?'value'.+)$/

    csv
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, acc ->
      cond do
        String.match?(line, regex) ->
          %{"value" => value} = Regex.named_captures(regex, line)

          acc
          |> Map.put(:current_key, value)
          |> Map.put(value, %{})

        String.match?(line, regex_for_kv) ->
          %{"title" => title, "value" => value} = Regex.named_captures(regex_for_kv, line)

          current_values = acc[acc[:current_key]]
          updated_values = Map.put(current_values, title, value)
          Map.put(acc, acc[:current_key], updated_values)

        true ->
          acc
      end
    end)
    |> Map.drop([:current_key])
  end
end
