defmodule BarragensptWeb.DashboardLive do
  use BarragensptWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    signed_in? = socket.assigns.current_scope.user != nil
    {:ok, assign(socket, :signed_in?, signed_in?)}
  end

  defp dashboard_link_attrs(%{user: user}, path) when not is_nil(user), do: [navigate: path]
  defp dashboard_link_attrs(_scope, path), do: [href: path]
end
