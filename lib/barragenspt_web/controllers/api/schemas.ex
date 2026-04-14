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
      title: "Metadados da barragem",
      description:
        "Conjunto alargado de características descritivas da barragem (estrutura chave/valor).",
      type: :object,
      properties: %{
        additionalProperties: %OpenApiSpex.Schema{
          type: :object,
          properties: %{
            nome: %OpenApiSpex.Schema{type: :string},
            valor: %OpenApiSpex.Schema{type: :integer}
          }
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
      title: "Resposta de metadados da barragem",
      description: "Metadados da barragem com hiperligações relacionadas.",
      type: :object,
      properties: %{
        data: DamInfo,
        links: %Schema{
          type: :string,
          description: "Hiperligações relacionadas com o recurso",
          properties: %{
            self: %Schema{type: :string, description: "Hiperligação para este recurso"},
            snapshot: %Schema{
              type: :string,
              description: "Hiperligação para o instantâneo hidrométrico"
            },
            basin: %Schema{type: :string, description: "Hiperligação para a bacia"},
            collection: %Schema{
              type: :string,
              description: "Hiperligação para a coleção de barragens na bacia"
            }
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
      title: "Instantâneo hidrométrico (modelo detalhado)",
      description:
        "Últimos valores conhecidos por parâmetro: médias diárias e leituras de última hora.",
      type: :object,
      properties: %{
        daily_average: %Schema{
          type: :object,
          description: "Médias diárias por parâmetro.",
          properties: %{
            effluent_daily_flow: %Schema{
              type: :object,
              description: "Caudal efluente médio diário (m³/s).",
              properties: %{
                param_id: %Schema{
                  type: :string,
                  description: "Identificador do parâmetro no SNIRH."
                },
                value: %Schema{type: :number, description: "Valor medido."},
                collected_at: %Schema{type: :datetime, description: "Data da recolha."}
              }
            },
            elevation: %Schema{
              type: :object,
              description: "Cota da albufeira (m) — média diária.",
              properties: %{
                param_id: %Schema{
                  type: :string,
                  description: "Identificador do parâmetro no SNIRH."
                },
                value: %Schema{type: :number, description: "Valor medido."},
                collected_at: %Schema{type: :datetime, description: "Data da recolha."}
              }
            },
            ouput_flow_rate_daily: %Schema{
              type: :object,
              description: "Caudal descarregado médio diário (m³/s).",
              properties: %{
                param_id: %Schema{
                  type: :string,
                  description: "Identificador do parâmetro no SNIRH."
                },
                value: %Schema{type: :number, description: "Valor medido."},
                collected_at: %Schema{type: :datetime, description: "Data da recolha."}
              }
            },
            tributary_daily_flow: %Schema{
              type: :object,
              description: "Caudal afluente médio diário (m³/s).",
              properties: %{
                param_id: %Schema{
                  type: :string,
                  description: "Identificador do parâmetro no SNIRH."
                },
                value: %Schema{type: :number, description: "Valor medido."},
                collected_at: %Schema{type: :datetime, description: "Data da recolha."}
              }
            },
            turbocharged_daily_flow: %Schema{
              type: :object,
              description: "Caudal turbinado médio diário (m³/s).",
              properties: %{
                param_id: %Schema{
                  type: :string,
                  description: "Identificador do parâmetro no SNIRH."
                },
                value: %Schema{type: :number, description: "Valor medido."},
                collected_at: %Schema{type: :datetime, description: "Data da recolha."}
              }
            },
            volume: %Schema{
              type: :object,
              description: "Volume armazenado (dam³) — média diária.",
              properties: %{
                param_id: %Schema{
                  type: :string,
                  description: "Identificador do parâmetro no SNIRH."
                },
                value: %Schema{type: :number, description: "Valor medido."},
                collected_at: %Schema{type: :datetime, description: "Data da recolha."}
              }
            },
            volume_last_day_month: %Schema{
              type: :object,
              description: "Volume armazenado no último dia do mês (dam³).",
              properties: %{
                param_id: %Schema{
                  type: :string,
                  description: "Identificador do parâmetro no SNIRH."
                },
                value: %Schema{type: :number, description: "Valor medido."},
                collected_at: %Schema{type: :datetime, description: "Data da recolha."}
              }
            }
          }
        },
        realtime: %Schema{
          type: :object,
          description: "Leituras em tempo real por parâmetro.",
          properties: %{
            elevation: %Schema{
              type: :object,
              description: "Cota da albufeira",
              properties: %{
                param_id: %Schema{
                  type: :string,
                  description: "Identificador do parâmetro."
                },
                value: %Schema{type: :number, description: "Valor medido."},
                collected_at: %Schema{type: :datetime, description: "Data da recolha."}
              }
            },
            volume: %Schema{
              type: :object,
              description: "Volume armazenado.",
              properties: %{
                param_id: %Schema{
                  type: :string,
                  description: "Identificador do parâmetro."
                },
                value: %Schema{type: :number, description: "Valor medido."},
                collected_at: %Schema{type: :datetime, description: "Data da recolha."}
              }
            },
            effluent_flow: %Schema{
              type: :object,
              description: "Caudal efluente.",
              properties: %{
                param_id: %Schema{
                  type: :string,
                  description: "Identificador do parâmetro."
                },
                value: %Schema{type: :number, description: "Valor medido."},
                collected_at: %Schema{type: :datetime, description: "Data da recolha."}
              }
            },
            tributary_flow: %Schema{
              type: :object,
              description: "Caudal afluente.",
              properties: %{
                param_id: %Schema{
                  type: :string,
                  description: "Identificador do parâmetro."
                },
                value: %Schema{type: :number, description: "Valor medido."},
                collected_at: %Schema{type: :datetime, description: "Data da recolha."}
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
      title: "Resposta de instantâneo da barragem",
      description:
        "Instantâneo hidrométrico da barragem com hiperligações para o recurso e para a bacia.",
      type: :object,
      properties: %{
        data: DamSnapshot,
        links: %Schema{
          type: :object,
          description: "Hiperligações relacionadas com o recurso",
          properties: %{
            self: %Schema{type: :string, description: "URL para este snapshot"},
            basin: %Schema{type: :string, description: "URL para a bacia hidrográfica"},
            collection: %Schema{
              type: :string,
              description: "URL para a listagem de todas as barragens da bacia hidrográfica."
            }
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

  defmodule BasinSummary do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Resumo de bacia hidrográfica",
      description:
        "Agregado por bacia para o dia e mês correntes: volumes totais armazenados e capacidade.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Identificador da bacia."},
        name: %Schema{type: :string, description: "Nome da bacia."},
        current_storage_volume: %Schema{
          type: :number,
          nullable: true,
          description:
            "Média ponderada do parâmetro `volume_last_hour` mais recente de todas as barragens da bacia (hm³, arredondado). A média é ponderada pela capacidade total de cada barragem."
        },
        historical_average_volume: %Schema{
          type: :number,
          nullable: true,
          description:
            "Volume armazenado médio histórico da bacia (hm³, arredondado) à data corrente.. A média é ponderada pela capacidade total de cada barragem."
        },
        total_capacity: %Schema{
          type: :number,
          nullable: true,
          description: "Soma das capacidades máximas projetadas das barragens de uma bacia."
        }
      },
      example: %{
        "id" => "1",
        "name" => "Rio Mondego",
        "current_storage_volume" => 1_250_000,
        "historical_average_volume" => 1_180_000,
        "total_capacity" => 2_100_000
      }
    })
  end

  defmodule BasinListResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Lista de bacias hidrográficas",
      description: "Lista de bacias hidrográficas com resumo agregado.",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: BasinSummary},
        links: %Schema{
          type: :object,
          properties: %{
            self: %Schema{type: :string, description: "URL para esta listagem."},
            basin: %Schema{
              type: :string,
              description:
                "URL de detalhe de uma bacia hidrográfica. Substituir `{id}` pelo identificador da bacia."
            }
          }
        }
      },
      example: %{
        "data" => [
          %{
            "id" => "1",
            "name" => "Rio Mondego",
            "current_storage_volume" => 1_250_000,
            "historical_average_volume" => 1_180_000,
            "total_capacity" => 2_100_000
          }
        ],
        "links" => %{
          "self" => "https://example.com/api/basins",
          "basin" => "https://example.com/api/basins/{id}"
        }
      }
    })
  end

  defmodule BasinDetailResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Detalhe de bacia hidrográfica",
      description: "Detalhe de uma bacia hidrográfica com resumo agregado.",
      type: :object,
      properties: %{
        data: BasinSummary,
        links: %Schema{
          type: :object,
          properties: %{
            dams: %Schema{
              type: :string,
              description: "URL para a lista de barragens da bacia hidrográfica."
            }
          }
        }
      },
      example: %{
        "data" => %{
          "id" => "1",
          "name" => "Rio Mondego",
          "current_storage_volume" => 1_250_000,
          "historical_average_volume" => 1_180_000,
          "total_capacity" => 2_100_000
        },
        "links" => %{
          "dams" => "https://example.com/api/basins/1/dams"
        }
      }
    })
  end

  defmodule BasinDamListResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Resposta — barragens numa bacia",
      description: "Lista de instantâneos hidrométricos por barragem na bacia indicada.",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: BasinSummary},
        links: %Schema{
          type: :object,
          properties: %{
            self: %Schema{type: :string, description: "Hiperligação para esta listagem."},
            basin: %Schema{type: :string, description: "Hiperligação para a bacia."},
            dam: %Schema{
              type: :string,
              description:
                "Modelo de URL; substituir `{site_id}` pelo identificador de site da barragem."
            }
          }
        }
      },
      example: %{
        "data" => [
          BasinSummary.schema().example
          |> Map.put("historical_average_volume", 128_000)
        ],
        "links" => %{
          "self" => "https://example.com/api/basins/1/dams",
          "basin" => "https://example.com/api/basins/1",
          "dam" => "https://example.com/api/basins/1/dams/{site_id}"
        }
      }
    })
  end
end
