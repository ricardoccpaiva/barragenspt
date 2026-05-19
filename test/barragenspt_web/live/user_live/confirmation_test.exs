defmodule BarragensptWeb.UserLive.ConfirmationTest do
  use BarragensptWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Barragenspt.AccountsFixtures

  alias Barragenspt.Accounts

  setup do
    %{unconfirmed_user: unconfirmed_user_fixture(), confirmed_user: user_fixture()}
  end

  describe "Confirm user" do
    test "renders confirmation page for unconfirmed user", %{conn: conn, unconfirmed_user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/users/confirm/#{token}")
      assert html =~ "Confirmar conta"
      assert html =~ "Confirmar e-mail"
    end

    test "renders login page for confirmed user", %{conn: conn, confirmed_user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/users/confirm/#{token}")
      assert html =~ "Esta conta já está confirmada"
    end

    test "confirms the given token once", %{conn: conn, unconfirmed_user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/confirm/#{token}")

      form = form(lv, "#confirmation_form", %{})
      render_submit(form)

      {:ok, _lv, html} = follow_redirect(form, conn, ~p"/users/log-in")

      assert html =~ "Conta confirmada com sucesso"
      assert Accounts.get_user!(user.id).confirmed_at

      {:ok, _lv, html} =
        live(build_conn(), ~p"/users/confirm/#{token}")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "O link de confirmação é inválido ou expirou"
    end

    test "raises error for invalid token", %{conn: conn} do
      {:ok, _lv, html} =
        live(conn, ~p"/users/confirm/invalid-token")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "O link de confirmação é inválido ou expirou"
    end
  end
end
