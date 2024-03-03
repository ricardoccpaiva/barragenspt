defmodule Barragenspt.Services.Snirh do
  @timeout 25000
  @base_url Application.compile_env!(:barragenspt, :snirh)[:csv_data_url]

  def get_raw_csv_data(site_id, parameter_id, start_date, end_date) do
    query_params =
      "?sites=#{site_id}&pars=#{parameter_id}&tmin=#{start_date}&tmax=#{end_date}&formato=csv"

    options = [recv_timeout: @timeout, timeout: @timeout]
    %HTTPoison.Response{body: body} = HTTPoison.get!(@base_url <> query_params, [], options)

    body
  end

  def dam_info(basin_id, site_id) do
    url =
      "snirh/_dadosbase/site/simplex.php?OBJINFO=INFO&FILTRA_BACIA=#{basin_id}&FILTRA_COVER=920123705&FILTRA_SITE=#{site_id}"

    middleware = [{Tesla.Middleware.BaseUrl, "https://snirh.apambiente.pt/"}]

    middleware
    |> Tesla.client()
    |> Tesla.get(url)
    |> then(fn {:ok, response} -> response.body end)
    |> Codepagex.to_string(:iso_8859_1)
    |> then(fn {:ok, value} -> value end)
  end

  def dam_data() do
    middleware = [
      {Tesla.Middleware.BaseUrl, "https://snirh.apambiente.pt/"},
      Tesla.Middleware.FormUrlencoded,
      {Tesla.Middleware.Headers,
       [
         {"Accept-Encoding", "deflate"},
         {"Content-Type", "application/x-www-form-urlencoded"}
       ]}
    ]

    params = %{
      "accao" => "go",
      "tipo_entrada" => "0",
      "form_estacao" => "",
      "form_rede[1]" => "920123705",
      "f_divisao_administrativa" => "",
      "f_curso_agua" => ""
    }

    middleware
    |> Tesla.client()
    |> Tesla.post("index.php?idMain=2&idItem=3", params)
    |> then(fn {:ok, response} -> response.body end)
    |> Codepagex.to_string(:iso_8859_1)
    |> then(fn {:ok, value} -> value end)
  end
end
