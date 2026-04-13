defmodule BarragensptWeb.Api.Schemas.SnapshotExample do
  @moduledoc false

  @doc false
  def map do
    %{
      "daily_average" => %{
        "effluent_daily_flow" => %{
          "param_id" => "212296818",
          "value" => 12.4,
          "collected_at" => "2026-04-12T23:00:00Z"
        },
        "elevation" => %{
          "param_id" => "1629599726",
          "value" => 108.32,
          "collected_at" => "2026-04-12T23:00:00Z"
        },
        "ouput_flow_rate_daily" => %{
          "param_id" => "2284",
          "value" => 45.0,
          "collected_at" => "2026-04-12T23:00:00Z"
        },
        "tributary_daily_flow" => %{
          "param_id" => "2279",
          "value" => 8.1,
          "collected_at" => "2026-04-12T23:00:00Z"
        },
        "turbocharged_daily_flow" => %{
          "param_id" => "2282",
          "value" => 0.0,
          "collected_at" => "2026-04-12T23:00:00Z"
        },
        "volume" => %{
          "param_id" => "1629599798",
          "value" => 125_430.0,
          "collected_at" => "2026-04-12T23:00:00Z"
        },
        "volume_last_day_month" => %{
          "param_id" => "304545050",
          "value" => 124_800.0,
          "collected_at" => "2026-04-12T23:00:00Z"
        }
      },
      "realtime" => %{
        "elevation" => %{
          "param_id" => "354895424",
          "value" => 108.45,
          "collected_at" => "2026-04-13T08:15:00Z"
        },
        "volume" => %{
          "param_id" => "354895398",
          "value" => 125_500.0,
          "collected_at" => "2026-04-13T08:15:00Z"
        },
        "effluent_flow" => %{
          "param_id" => "212296818",
          "value" => 15.2,
          "collected_at" => "2026-04-13T08:15:00Z"
        },
        "tributary_flow" => %{
          "param_id" => "2279",
          "value" => 9.8,
          "collected_at" => "2026-04-13T08:15:00Z"
        }
      }
    }
  end
end

defmodule BarragensptWeb.Api.Schemas do
  alias OpenApiSpex.Schema

  defmodule DamInfo do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Dam metadatainformation",
      description: "An extended list of characteristics of a dam",
      type: :object,
      properties: %{
        additionalProperties: %Schema{
          type: :object,
          additionalProperties: %Schema{type: :string}
        }
      },
      example: %{
        "Albufeira" => %{
          "Capacidade total (dam3)" => "136000",
          "Cota do nível de máxima cheia - NMC (m)" => "112",
          "Cota do nível de pleno armazenamento - NPA (m)" => "110",
          "Cota do nível mínimo de exploração - NmE (m)" => "85",
          "Existe bacia drenante em Espanha" => "Não mencionado",
          "Nome" => "Ribeiradio",
          "Superfície inundável ao NPA (ha)" => "N/A",
          "Tipos de aproveitamento" => "Hidroelétrico"
        },
        "Bacia Hidrográfica" => %{
          "Área da bacia hidrográfica total (km2)" => "4100"
        }
      }
    })
  end

  defmodule DamInfoResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "UserResponse",
      description: "Response schema for single user",
      type: :object,
      properties: %{
        data: DamInfo,
        links: %Schema{
          type: :string,
          description: "Entity related links",
          properties: %{
            self: %Schema{type: :string, description: "Self link"},
            snapshot: %Schema{type: :string, description: "Snapshot link"},
            basin: %Schema{type: :string, description: "Basin link"},
            collection: %Schema{type: :string, description: "Collection link"}
          }
        }
      },
      example: %{
        "data" => %{
          "Albufeira" => %{
            "Capacidade total (dam3)" => "136000",
            "Cota do nível de máxima cheia - NMC (m)" => "112",
            "Cota do nível de pleno armazenamento - NPA (m)" => "110",
            "Cota do nível mínimo de exploração - NmE (m)" => "85",
            "Existe bacia drenante em Espanha" => "Não mencionado",
            "Nome" => "Ribeiradio",
            "Superfície inundável ao NPA (ha)" => "N/A",
            "Tipos de aproveitamento" => "Hidroelétrico"
          },
          "Bacia Hidrográfica" => %{
            "Área da bacia hidrográfica total (km2)" => "4100"
          }
        },
        "links" => %{
          "self" => "https://example.com/api/dams/123/info",
          "snapshot" => "https://example.com/api/dams/123",
          "basin" => "https://example.com/api/basins/123",
          "collection" => "https://example.com/api/basins/123/dams"
        }
      }
    })
  end

  defmodule DamSnapshot do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Dam snapshot",
      description: "The last known values for a dam's datapoints",
      type: :object,
      properties: %{
        daily_average: %Schema{
          type: :object,
          properties: %{
            effluent_daily_flow: %Schema{
              type: :object,
              properties: %{
                param_id: %Schema{type: :string},
                value: %Schema{type: :number},
                collected_at: %Schema{type: :datetime}
              }
            },
            elevation: %Schema{
              type: :object,
              properties: %{
                param_id: %Schema{type: :string},
                value: %Schema{type: :number},
                collected_at: %Schema{type: :datetime}
              }
            },
            ouput_flow_rate_daily: %Schema{
              type: :object,
              properties: %{
                param_id: %Schema{type: :string},
                value: %Schema{type: :number},
                collected_at: %Schema{type: :datetime}
              }
            },
            tributary_daily_flow: %Schema{
              type: :object,
              properties: %{
                param_id: %Schema{type: :string},
                value: %Schema{type: :number},
                collected_at: %Schema{type: :datetime}
              }
            },
            turbocharged_daily_flow: %Schema{
              type: :object,
              properties: %{
                param_id: %Schema{type: :string},
                value: %Schema{type: :number},
                collected_at: %Schema{type: :datetime}
              }
            },
            volume: %Schema{
              type: :object,
              properties: %{
                param_id: %Schema{type: :string},
                value: %Schema{type: :number},
                collected_at: %Schema{type: :datetime}
              }
            },
            volume_last_day_month: %Schema{
              type: :object,
              properties: %{
                param_id: %Schema{type: :string},
                value: %Schema{type: :number},
                collected_at: %Schema{type: :datetime}
              }
            }
          }
        },
        realtime: %Schema{
          type: :object,
          properties: %{
            elevation: %Schema{
              type: :object,
              properties: %{
                param_id: %Schema{type: :string},
                value: %Schema{type: :number},
                collected_at: %Schema{type: :datetime}
              }
            },
            volume: %Schema{
              type: :object,
              properties: %{
                param_id: %Schema{type: :string},
                value: %Schema{type: :number},
                collected_at: %Schema{type: :datetime}
              }
            },
            effluent_flow: %Schema{
              type: :object,
              properties: %{
                param_id: %Schema{type: :string},
                value: %Schema{type: :number},
                collected_at: %Schema{type: :datetime}
              }
            },
            tributary_flow: %Schema{
              type: :object,
              properties: %{
                param_id: %Schema{type: :string},
                value: %Schema{type: :number},
                collected_at: %Schema{type: :datetime}
              }
            }
          }
        }
      },
      example: BarragensptWeb.Api.Schemas.SnapshotExample.map()
    })
  end

  defmodule DamSnapshotResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Dam snapshot response",
      description: "Contains the last know values for a dam's datapoints",
      type: :object,
      properties: %{
        data: DamSnapshot,
        links: %Schema{
          type: :string,
          description: "Entity related links",
          properties: %{
            self: %Schema{type: :string, description: "Self link"},
            snapshot: %Schema{type: :string, description: "Snapshot link"},
            basin: %Schema{type: :string, description: "Basin link"},
            collection: %Schema{type: :string, description: "Collection link"}
          }
        }
      },
      example: %{
        "data" => BarragensptWeb.Api.Schemas.SnapshotExample.map(),
        "links" => %{
          "self" => "https://example.com/api/dams/7554777512",
          "basin" => "https://example.com/api/basins/1",
          "collection" => "https://example.com/api/basins/1/dams"
        }
      }
    })
  end
end
