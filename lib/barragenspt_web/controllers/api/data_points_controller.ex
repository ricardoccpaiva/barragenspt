defmodule BarragensptWeb.Api.DataPointsController do
  use BarragensptWeb, :controller

  alias Barragenspt.Hydrometrics.DataPointParams

  def param_catalog(conn, _params) do
    json(conn, %{data: DataPointParams.all()})
  end
end
