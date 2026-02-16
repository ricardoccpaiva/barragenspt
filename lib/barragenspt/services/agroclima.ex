defmodule Barragenspt.Services.Agroclima do
  @moduledoc """
  Cliente para a API do Agroclima (IPMA). Obtém sessão/cookie e token CSRF
  (atributo csrft no HTML) e faz POST ao evomaptimeval para dados SMI por concelho.
  """
  require Logger

  @base_url "https://agroclima.ipma.pt"
  @clievo_url "#{@base_url}/clievo"
  @evomaptimeval_url "#{@base_url}/evomaptimeval"
  @timeout 15_000

  @valid_vser ~w(p7 p28 p100)

  @doc """
  Obtém valores SMI por feature (concelho) para o timestamp e profundidade dados.
  vtim = Unix timestamp em milissegundos (início do dia).
  vser = profundidade na API: "p7", "p28" ou "p100" (default "p28").
  Retorna `{:ok, data}` com o JSON decodificado ou `{:error, reason}`.
  """
  def get_smi_values(vtim, vser \\ "p28")
  def get_smi_values(vtim, vser) when is_integer(vtim),
    do: get_smi_values(to_string(vtim), vser)
  def get_smi_values(vtim, vser) when is_binary(vtim) do
    vser = if vser in @valid_vser, do: vser, else: "p28"
    with {:ok, cookie_header, csrf_token} <- fetch_session_and_csrf(),
         {:ok, data} <- post_evomaptimeval(vtim, vser, cookie_header, csrf_token) do
      {:ok, data}
    end
  end

  @doc """
  Obtém cookie de sessão e token CSRF da página clievo.
  O token vem no atributo `csrft` do div#mapchartcont.
  """
  def fetch_session_and_csrf do
    opts = [recv_timeout: @timeout, follow_redirect: true]

    case HTTPoison.get(@clievo_url, [], opts) do
      {:ok, %{headers: headers, body: body}} ->
        cookie_header =
          case Enum.find(headers, fn {k, _} -> String.downcase(k) == "set-cookie" end) do
            {_, v} -> v
            nil -> ""
          end

        csrf_token = parse_csrft_from_html(body)

        if csrf_token != nil and csrf_token != "" and cookie_header != "" do
          {:ok, cookie_header, csrf_token}
        else
          {:error, :no_csrf}
        end

      _ ->
        {:error, :get_failed}
    end
  end

  defp parse_csrft_from_html(html) when is_binary(html) do
    case Floki.parse_document(html) do
      {:ok, doc} ->
        doc
        |> Floki.find("#mapchartcont")
        |> Floki.attribute("csrft")
        |> List.first()

      _ ->
        nil
    end
  end

  defp parse_csrft_from_html(_), do: nil

  defp post_evomaptimeval(vtim, vser, cookie_header, csrf_token) do
    body =
      "csrfmiddlewaretoken=#{URI.encode_www_form(csrf_token)}&vcod=smi&vlev=conc&vser=#{vser}&vtmp=dd&vzon=PT100&vtim=#{vtim}"

    headers = [
      {"x-requested-with", "XMLHttpRequest"},
      {"origin", @base_url},
      {"referer", @clievo_url},
      {"content-type", "application/x-www-form-urlencoded; charset=UTF-8"},
      {"cookie", cookie_header}
    ]

    opts = [recv_timeout: @timeout]

    case HTTPoison.post(@evomaptimeval_url, body, headers, opts) do
      {:ok, %{status_code: 200, body: response_body}} ->
        {:ok, Jason.decode!(response_body)}

      {:ok, %{status_code: code, body: body}} ->
        Logger.warning("Agroclima evomaptimeval status=#{code} body=#{String.slice(body, 0..200)}")
        {:error, :upstream}

      {:error, reason} ->
        Logger.warning("Agroclima evomaptimeval error: #{inspect(reason)}")
        {:error, :upstream}
    end
  end
end
