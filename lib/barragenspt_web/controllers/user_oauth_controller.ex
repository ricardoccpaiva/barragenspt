defmodule BarragensptWeb.UserOAuthController do
  use BarragensptWeb, :controller

  plug Ueberauth

  alias Barragenspt.Accounts
  alias BarragensptWeb.UserAuth

  def request(conn, _params) do
    conn
    |> put_flash(:error, "Não foi possível iniciar login com Google.")
    |> redirect(to: ~p"/users/log-in")
  end

  def callback(%{assigns: %{ueberauth_auth: %{provider: :google} = auth}} = conn, _params) do
    email = auth.info.email || ""

    case Accounts.find_or_create_google_user(email) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Sessão iniciada com Google.")
        |> UserAuth.log_in_user(user, %{"remember_me" => "true"})

      {:error, :missing_email} ->
        conn
        |> put_flash(:error, "A conta Google não devolveu um email válido.")
        |> redirect(to: ~p"/users/log-in")

      {:error, _} ->
        conn
        |> put_flash(:error, "Não foi possível concluir o login com Google.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  def callback(%{assigns: %{ueberauth_failure: _failure}} = conn, _params) do
    conn
    |> put_flash(:error, "Falha no login com Google. Tente novamente.")
    |> redirect(to: ~p"/users/log-in")
  end
end
