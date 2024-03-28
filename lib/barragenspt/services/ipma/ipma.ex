defmodule Barragenspt.Services.Ipma do
  @timeout 50000

  def get_image(indicator, year, month, :png, layer) do
    get(indicator, year, month, "image/png", layer)
  end

  def get_image(indicator, year, month, :svg, layer) do
    get(indicator, year, month, "image/svg+xml", layer)
  end

  def get_image(indicator, year, month, day, :svg, layer) do
    get(indicator, year, month, day, "image/svg+xml", layer)
  end

  def get_image(indicator, year, month, day, :png, layer) do
    get(indicator, year, month, day, "image/png", layer)
  end

  defp get(:pdsi, year, month, format, layer) do
    get_internal("PalmerDroughtSeverityIndex", year, month, format, layer)
  end

  defp get(:precipitation, year, month, format, layer) do
    get_internal("precipitation", year, month, format, layer)
  end

  defp get(:precipitation, year, month, day, format, layer) do
    get_internal("precipitation", year, month, day, format, layer)
  end

  defp get(:temperature, year, month, day, format, layer) do
    get_internal("temperature", year, month, day, format, layer)
  end

  defp get(:smi, year, month, day, format, layer) do
    get_internal("SoilMoistureIndex", year, month, day, format, layer)
  end

  defp get_internal(indicator, year, month, format, layer) do
    format = URI.encode_www_form(format)

    month =
      month
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    base_url =
      "https://mapservices.ipma.pt/observations/climate/#{indicator}/wms"

    url =
      "#{base_url}?service=WMS&request=GetMap&layers=#{layer}&styles&format=#{format}&transparent=true&version=1.1.1&time=#{year}-#{month}-01T00%3A00%3A00Z&width=404&height=774&srs=EPSG%3A3857&bbox=-1094009.7446,4438339.9340,-689199.2428,5212494.1564"

    http_get(url)
  end

  defp get_internal(indicator, year, month, day, format, layer) do
    format = URI.encode_www_form(format)

    month =
      month
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    day =
      day
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    base_url =
      "https://mapservices.ipma.pt/observations/climate/#{indicator}/wms"

    url =
      "#{base_url}?service=WMS&request=GetMap&layers=#{layer}&styles&format=#{format}&transparent=true&version=1.1.1&time=#{year}-#{month}-#{day}T00%3A00%3A00Z&width=404&height=774&srs=EPSG%3A3857&bbox=-1094009.7446,4438339.9340,-689199.2428,5212494.1564"

    http_get(url)
  end

  defp http_get(url) do
    options = [recv_timeout: @timeout, timeout: @timeout]
    %HTTPoison.Response{body: body} = HTTPoison.get!(url, [], options)

    body
  end
end
