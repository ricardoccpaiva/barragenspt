defmodule Barragenspt.Services.EmbalsesNet do
  def basins_info do
    url = "cuencas.php"

    middleware = [{Tesla.Middleware.BaseUrl, "https://www.embalses.net/"}]

    middleware
    |> Tesla.client()
    |> Tesla.get(url)
    |> then(fn {:ok, response} -> response.body end)
  end
end
