defmodule Barragenspt.Services.Ipma.TeslaClient do
  # build dynamic client based on runtime arguments
  def client() do
    middleware = [
      {Tesla.Middleware.Retry, delay: 500, max_retries: 3, max_delay: 4_000},
      {Tesla.Middleware.Timeout, timeout: 10_000},
      {Tesla.Middleware.Cache, ttl: :timer.hours(720)}
    ]

    Tesla.client(middleware)
  end
end

# build dynamic client based on runtime arguments  use Tesla
defmodule Barragenspt.Services.BarragensPtClient do
  use Tesla

  def get_wms_pdsi(url) do
    get("http://localhost:4000/wms_pdsi#{url}")
  end

  def get_wms_precipitation(url) do
    get("http://localhost:4000/wms_precipitation#{url}")
  end
end
