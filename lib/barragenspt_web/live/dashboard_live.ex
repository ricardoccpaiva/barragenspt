defmodule BarragensptWeb.DashboardLive do
  use BarragensptWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    signed_in? = socket.assigns.current_scope.user != nil
    {:ok, assign(socket, :signed_in?, signed_in?)}
  end

  defp dashboard_link_attrs(%{user: user}, path) when not is_nil(user), do: [navigate: path]
  defp dashboard_link_attrs(_scope, path), do: [href: path]

  defp user_display_name(%{display_name: name, email: email}) do
    case to_string(name || "") |> String.trim() do
      "" -> email |> to_string() |> String.split("@") |> List.first()
      value -> value
    end
  end

  defp user_display_name(_), do: "utilizador"
end
