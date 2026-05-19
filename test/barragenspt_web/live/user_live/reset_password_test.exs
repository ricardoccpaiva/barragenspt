defmodule BarragensptWeb.UserLive.ResetPasswordTest do
  use BarragensptWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Barragenspt.AccountsFixtures

  alias Barragenspt.Accounts

  describe "reset password page" do
    test "renders page for valid token", %{conn: conn} do
      user = user_fixture()
      {token, _hashed_token} = generate_user_reset_password_token(user)

      {:ok, _lv, html} = live(conn, ~p"/users/reset-password/#{token}")

      assert html =~ "Nova palavra-passe"
      assert html =~ user.email
    end

    test "redirects when token is invalid", %{conn: conn} do
      {:ok, _lv, html} =
        live(conn, ~p"/users/reset-password/invalid-token")
        |> follow_redirect(conn, ~p"/users/reset-password")

      assert html =~ "O link para redefinir a palavra-passe é inválido ou expirou"
    end

    test "resets password from valid token", %{conn: conn} do
      user = user_fixture() |> set_password()
      {token, _hashed_token} = generate_user_reset_password_token(user)
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password/#{token}")

      {:ok, _lv, html} =
        form(lv, "#reset_password_form",
          user: %{password: "Another!1", password_confirmation: "Another!1"}
        )
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Palavra-passe redefinida com sucesso"
      assert Accounts.get_user_by_email_and_password(user.email, "Another!1")
    end

    test "shows validation errors on invalid submit", %{conn: conn} do
      user = user_fixture()
      {token, _hashed_token} = generate_user_reset_password_token(user)
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password/#{token}")

      html =
        form(lv, "#reset_password_form",
          user: %{password: "short", password_confirmation: "mismatch"}
        )
        |> render_submit()

      assert html =~ "should be at least 8 character(s)"
      assert html =~ "does not match password"
    end
  end
end
