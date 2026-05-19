defmodule BarragensptWeb.UserLive.ForgotPasswordTest do
  use BarragensptWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Barragenspt.AccountsFixtures

  alias Barragenspt.Accounts.UserToken
  alias Barragenspt.Repo

  describe "forgot password page" do
    test "renders forgot password page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/reset-password")

      assert html =~ "Recuperar palavra-passe"
      assert html =~ "Enviar instruções"
    end

    test "sends reset instructions when the user exists", %{conn: conn} do
      user = user_fixture()
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password")

      {:ok, _lv, html} =
        form(lv, "#forgot_password_form", user: %{email: user.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Se esse e-mail existir na nossa base de dados"
      assert Repo.get_by!(UserToken, user_id: user.id, context: "reset_password")
    end

    test "does not disclose if user is registered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password")

      {:ok, _lv, html} =
        form(lv, "#forgot_password_form", user: %{email: "idonotexist@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Se esse e-mail existir na nossa base de dados"
    end
  end
end
