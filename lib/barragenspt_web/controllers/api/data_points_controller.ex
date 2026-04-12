defmodule BarragensptWeb.Api.DataPointsController do
  use BarragensptWeb, :controller

  alias Barragenspt.Hydrometrics.{Dams, DataPointParams}

  def index(conn, params) do
    case Dams.list_data_points_api(params) do
      {:ok, {rows, meta}} ->
        conn
        |> put_view(BarragensptWeb.Api.DataPointsView)
        |> render("index.json", rows: rows, meta: meta)

      {:error, %Flop.Meta{} = meta} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          errors: [
            %{
              title: "Bad Request",
              detail: flop_meta_error_detail(meta)
            }
          ]
        })
    end
  end

  def param_catalog(conn, _params) do
    json(conn, %{data: DataPointParams.all()})
  end

  defp flop_meta_error_detail(%Flop.Meta{errors: errors}) when errors == [] do
    "Invalid pagination or filter parameters."
  end

  defp flop_meta_error_detail(%Flop.Meta{errors: errors}) do
    errors
    |> Enum.map(fn {field, msgs} ->
      msgs = List.wrap(msgs)
      "#{field}: #{Enum.join(Enum.map(msgs, &inspect/1), ", ")}"
    end)
    |> Enum.join(" ")
  end
end
