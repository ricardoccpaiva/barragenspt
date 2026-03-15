defmodule Barragenspt.Search.LLMTools.Weather do
  @moduledoc false

  alias Barragenspt.Services.Agroclima
  alias Barragenspt.Search.LLMTools.Helpers

  def exec("get_drought_index", args), do: exec_get_drought_index(args)
  def exec("get_soil_moisture", args), do: exec_get_soil_moisture(args)
  def exec("get_precipitation", args), do: exec_get_precipitation(args)
  def exec(_, _), do: nil

  def exec_get_drought_index(_args) do
    {:ok,
     %{
       message:
         "PDSI (Palmer Drought Severity Index) integration is planned. Use get_soil_moisture or get_precipitation for current indices.",
       source: "IPMA/AgroClima"
     }}
  end

  def exec_get_soil_moisture(args) do
    depth = args["depth"] || "p28"
    depth = if depth in ~w(p7 p28 p100), do: depth, else: "p28"
    vtim = Helpers.today_start_ms()

    case Agroclima.get_smi_values(vtim, depth, "hidro") do
      {:ok, data} -> {:ok, %{depth: depth, data: data}}
      {:error, reason} -> {:error, "AgroClima error: #{inspect(reason)}"}
    end
  end

  def exec_get_precipitation(args) do
    agg = args["aggregation"] || "hidro"
    type = args["type"] || "anom"
    vser = if type == "tot", do: "tot", else: "anom"
    vtmp = if type == "tot", do: "dd", else: "ww"
    vtim = Helpers.today_start_ms()

    case Agroclima.get_prec_values(vtim, vser, vtmp, agg) do
      {:ok, data} ->
        data |> IO.inspect(label: "data--------->")
        {:ok, %{aggregation: agg, type: type, data: data}}

      {:error, reason} ->
        {:error, "AgroClima error: #{inspect(reason)}"}
    end
  end
end
