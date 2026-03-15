defmodule Barragenspt.Search.LLMTools.Navigation do
  @moduledoc false

  def exec("get_dam_url", args), do: exec_get_dam_url(args)
  def exec("get_basin_url", args), do: exec_get_basin_url(args)
  def exec(_, _), do: nil

  def exec_get_dam_url(%{"dam_id" => did, "basin_id" => bid}) when is_binary(did) and is_binary(bid) do
    base = BarragensptWeb.Endpoint.url()
    {:ok, %{url: "#{base}/basins/#{bid}/dams/#{did}"}}
  end

  def exec_get_dam_url(args) do
    did = args["dam_id"]
    bid = args["basin_id"]
    if did && bid do
      base = BarragensptWeb.Endpoint.url()
      {:ok, %{url: "#{base}/basins/#{bid}/dams/#{did}"}}
    else
      {:error, "dam_id and basin_id are required"}
    end
  end

  def exec_get_basin_url(%{"basin_id" => id}) when is_binary(id) do
    base = BarragensptWeb.Endpoint.url()
    {:ok, %{url: "#{base}/basins/#{id}"}}
  end

  def exec_get_basin_url(_), do: {:error, "basin_id is required"}
end
