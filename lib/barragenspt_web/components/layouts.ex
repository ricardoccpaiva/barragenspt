defmodule BarragensptWeb.Layouts do
  @moduledoc false
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: BarragensptWeb.Endpoint,
    router: BarragensptWeb.Router,
    statics: BarragensptWeb.static_paths()

  import BarragensptWeb.CoreComponents

  embed_templates "layouts/*"
end
