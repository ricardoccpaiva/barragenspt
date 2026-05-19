defmodule BarragensptWeb.ApiSpec do
  alias OpenApiSpex.{Components, Info, OpenApi, Paths, SecurityScheme, Server}
  alias BarragensptWeb.{Endpoint, Router}
  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        # Populate the Server info from a phoenix endpoint
        Server.from_endpoint(Endpoint)
      ],
      info: %Info{
        title: "API Barragens.pt",
        version: "1.0",
        description:
          """
          API JSON só de leitura para metadados de barragens, bacias hidrográficas e dados hidrométricos em Portugal.

          How to authenticate:
          - Gerar token em <a href="/dashboard/api-tokens" target="_top">/dashboard/api-tokens</a>
          - Enviar `Authorization: Bearer <YOUR_API_TOKEN>` em todos os pedidos à API
          """
      },
      components: %Components{
        securitySchemes: %{
          "bearerAuth" => %SecurityScheme{
            type: "http",
            scheme: "bearer",
            bearerFormat: "API token",
            description: "Token de API no header Authorization, formato: Bearer <token>."
          }
        }
      },
      security: [%{"bearerAuth" => []}],
      # Populate the paths from a phoenix router
      paths: Paths.from_router(Router)
    }
    # Discover request/response schemas from path specs
    |> OpenApiSpex.resolve_schema_modules()
  end
end
