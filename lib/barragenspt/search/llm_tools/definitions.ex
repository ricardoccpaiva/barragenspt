defmodule Barragenspt.Search.LLMTools.Definitions do
  @moduledoc false

  def list do
    [
      tool(
        "get_dam_storage",
        "Get current storage percentage for a dam by name.",
        %{dam_name: %{type: "string", description: "Dam name (e.g. Alqueva, Aguieira)"}},
        ["dam_name"]
      ),
      tool(
        "search_dams",
        "Search dams by name (partial match).",
        %{
          query: %{type: "string", description: "Search query"},
          usage_types: %{
            type: "array",
            items: %{type: "string"},
            description: "Filter by usage types (optional)"
          }
        },
        ["query"]
      ),
      tool(
        "get_dam_info",
        "Full info for a dam (name, basin, storage, usage, capacity).",
        %{
          dam_id: %{type: "string", description: "Dam site ID"},
          dam_name: %{type: "string", description: "Dam name (alternative to dam_id)"}
        },
        []
      ),
      tool(
        "get_dams_by_usage_type",
        "List dams filtered by usage (irrigation, hydropower, etc.).",
        %{
          usage_types: %{
            type: "array",
            items: %{type: "string"},
            description: "Usage types to filter"
          }
        },
        ["usage_types"]
      ),
      tool(
        "get_dam_storage_trend",
        "Storage evolution for a dam over a period.",
        %{
          dam_id: %{type: "string", description: "Dam site ID"},
          period: %{
            type: "string",
            enum: ["d7", "d14", "d30", "d60", "d180"],
            description: "Period (default d30)"
          }
        },
        ["dam_id"]
      ),
      tool(
        "get_dam_realtime",
        "Real-time inflow, outflow, level for a dam.",
        %{dam_id: %{type: "string", description: "Dam site ID"}},
        ["dam_id"]
      ),
      tool(
        "compare_dams",
        "Compare storage between 2-5 dams.",
        %{dam_names: %{type: "array", items: %{type: "string"}, description: "2 to 5 dam names"}},
        ["dam_names"]
      ),
      tool(
        "get_basin_storage",
        "Current storage summary for a basin.",
        %{
          basin_id: %{type: "string", description: "Basin ID"},
          basin_name: %{type: "string", description: "Basin name (alternative)"}
        },
        []
      ),
      tool(
        "list_basins",
        "List all Portuguese basins with current storage %.",
        %{
          usage_types: %{
            type: "array",
            items: %{type: "string"},
            description: "Filter by usage (optional)"
          }
        },
        []
      ),
      tool(
        "get_basin_dams",
        "Dams in a basin with storage.",
        %{
          basin_id: %{type: "string", description: "Basin ID"},
          usage_types: %{
            type: "array",
            items: %{type: "string"},
            description: "Filter (optional)"
          }
        },
        ["basin_id"]
      ),
      tool(
        "get_basin_storage_evolution",
        "Basin storage over time.",
        %{
          basin_id: %{type: "string", description: "Basin ID"},
          period: %{type: "integer", description: "Days (default 30)"}
        },
        ["basin_id"]
      ),
      tool(
        "search_rivers",
        "Search rivers by name.",
        %{query: %{type: "string", description: "Search query"}},
        ["query"]
      ),
      tool(
        "get_river_dams",
        "Dams on a river.",
        %{river_name: %{type: "string", description: "River name"}},
        ["river_name"]
      ),
      tool("get_spain_basins", "List Spanish basins with storage (embalses.net).", %{}, []),
      tool(
        "get_spain_basin_info",
        "Details for a Spanish basin.",
        %{basin_id: %{type: "string", description: "Spanish basin ID"}},
        ["basin_id"]
      ),
      tool(
        "get_drought_index",
        "PDSI (Palmer Drought Severity Index) for a region.",
        %{
          month: %{type: "integer", description: "Month (1-12, optional)"},
          aggregation: %{type: "string", description: "Aggregation level (optional)"}
        },
        []
      ),
      tool(
        "get_soil_moisture",
        "SMI (soil moisture index).",
        %{
          depth: %{
            type: "string",
            enum: ["p7", "p28", "p100"],
            description: "Depth (default p28)"
          }
        },
        []
      ),
      tool(
        "get_precipitation",
        "Precipitation data for region.",
        %{
          aggregation: %{type: "string", description: "Aggregation (conc, nuts3, etc.)"},
          type: %{type: "string", enum: ["anom", "tot"], description: "anom=anomaly, tot=total"}
        },
        []
      ),
      tool("get_flood_alerts", "Active flood/drought alerts by basin.", %{}, []),
      tool(
        "get_dam_url",
        "Direct URL to view a dam on the map.",
        %{
          dam_id: %{type: "string", description: "Dam site ID"},
          basin_id: %{type: "string", description: "Basin ID"}
        },
        ["dam_id", "basin_id"]
      ),
      tool(
        "get_basin_url",
        "Direct URL to view a basin.",
        %{basin_id: %{type: "string", description: "Basin ID"}},
        ["basin_id"]
      ),
      tool("get_usage_types", "List of dam usage types (irrigation, hydropower, etc.).", %{}, []),
      tool(
        "get_national_summary",
        "Portugal-wide storage summary.",
        %{
          usage_types: %{
            type: "array",
            items: %{type: "string"},
            description: "Filter (optional)"
          }
        },
        []
      ),
      tool(
        "get_dams_summary_stats",
        "List ALL dams with storage %. Use for: top N fullest/emptiest, ranking, discovery, 'quais as mais cheias', 'barragens com mais água'. Sort results by current_storage_pct to answer ranking questions.",
        %{},
        []
      ),
      tool("get_site_info", "About barragens.pt: mission, data sources, features.", %{}, [])
    ]
  end

  defp tool(name, description, properties, required) do
    %{
      "type" => "function",
      "function" => %{
        "name" => name,
        "description" => description,
        "parameters" => %{
          "type" => "object",
          "properties" => properties,
          "required" => required
        }
      }
    }
  end
end
