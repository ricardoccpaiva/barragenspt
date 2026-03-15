defmodule Barragenspt.Search.LLMTools do
  @moduledoc """
  LLM tools (function calling) for natural language Q&A on barragens.pt.
  Provides 25 tools that map to backend functions for dams, basins, rivers,
  Spain data, weather indices, alerts, and navigation.

  Delegates to domain modules in `Barragenspt.Search.LLMTools.*`:
  - `Dams` – dam-related tools
  - `Basins` – basin-related tools
  - `Rivers` – river-related tools
  - `Spain` – Spanish basin tools (embalses.net)
  - `Weather` – SMI, precipitation, PDSI stub
  - `Alerts` – flood/drought alerts
  - `Navigation` – dam/basin URLs
  - `Meta` – usage types, national summary, site info
  """

  alias Barragenspt.Search.LLMTools.{
    Definitions,
    Dams,
    Basins,
    Rivers,
    Spain,
    Weather,
    Alerts,
    Navigation,
    Meta
  }

  @doc """
  Returns the 25 tool definitions in OpenAI/Groq format.
  """
  def list_tools do
    Definitions.list()
  end

  @doc """
  Executes a tool by name with the given arguments.
  Returns `{:ok, result}` or `{:error, message}`.
  Result is JSON-serializable.
  """
  def execute_tool(tool_name, arguments) when is_map(arguments) do
    args =
      arguments
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Map.new()

    result =
      [Dams, Basins, Rivers, Spain, Weather, Alerts, Navigation, Meta]
      |> Enum.find_value(& &1.exec(tool_name, args))

    case result do
      nil -> {:error, "Unknown tool: #{tool_name}"}
      other -> other
    end
  end

  def execute_tool(tool_name, _), do: {:error, "Invalid arguments for #{tool_name}"}
end
