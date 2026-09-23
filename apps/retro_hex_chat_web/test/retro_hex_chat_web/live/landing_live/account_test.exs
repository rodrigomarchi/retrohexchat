defmodule RetroHexChatWeb.LandingLive.AccountTest do
  @moduledoc """
  The two pages an e-mail link lands on.

  Both are public and both exist under every locale segment — a first segment
  registered only unprefixed is how a shared link once became a router error for
  anybody browsing in another language, and the one thing nobody can fix about a
  link in an inbox is its URL.
  """
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Ecto.Query

  @moduletag :liveview

  alias RetroHexChat.Services.NickEmail
  alias RetroHexChat.Services.Queries
  alias RetroHexChat.Services.RegisteredNick

  @link_prefix "https://example.test/account/"

  setup do
    nick = "acct#{uid()}" |> String.slice(0, 16)
    {:ok, _} = Queries.insert_registered_nick(nick, "password123")
    %{nick: nick}
  end

  describe "confirming an address" do
    test "following the link confirms it", %{conn: conn, nick: nick} do
      token = set_email_and_capture(nick, "confirm@example.com")

      {:ok, _view, html} = live(conn, ~p"/account/verify/#{token}")

      assert html =~ ~s(data-testid="account-verified")
      assert RetroHexChat.Repo.get_by(RegisteredNick, nickname: nick).email_verified_at
    end

    test "a link already spent says so rather than pretending", %{conn: conn, nick: nick} do
      token = set_email_and_capture(nick, "spent@example.com")
      {:ok, _view, _html} = live(conn, ~p"/account/verify/#{token}")

      {:ok, _view, html} = live(conn, ~p"/account/verify/#{token}")

      assert html =~ ~s(data-testid="account-error")
      refute html =~ ~s(data-testid="account-verified")
    end

    test "a string that was never a token is refused", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/account/verify/not-a-token")

      assert html =~ ~s(data-testid="account-error")
    end

    test "the page exists under a locale segment too", %{conn: conn, nick: nick} do
      token = set_email_and_capture(nick, "locale@example.com")

      {:ok, _view, html} = live(conn, "/pt-BR/account/verify/#{token}")

      assert html =~ ~s(data-testid="account-verified")
    end
  end

  describe "choosing a new password" do
    setup %{nick: nick} do
      token = set_email_and_capture(nick, "reset@example.com")
      {:ok, ^nick} = NickEmail.verify_email(token)
      :ok = NickEmail.request_reset(nick, &link/1)
      %{reset_token: capture_token()}
    end

    test "the form changes the password", %{conn: conn, nick: nick, reset_token: token} do
      {:ok, view, html} = live(conn, ~p"/account/reset/#{token}")
      assert html =~ ~s(data-testid="account-reset-form")

      html =
        view
        |> element(~s([data-testid="account-reset-form"]))
        |> render_submit(%{"password" => "a-brand-new-password"})

      assert html =~ ~s(data-testid="account-reset-done")

      row = RetroHexChat.Repo.get_by(RegisteredNick, nickname: nick)
      assert RegisteredNick.verify_password(row, "a-brand-new-password")
    end

    test "a password the rules refuse keeps the form open", %{conn: conn, reset_token: token} do
      {:ok, view, _html} = live(conn, ~p"/account/reset/#{token}")

      html =
        view
        |> element(~s([data-testid="account-reset-form"]))
        |> render_submit(%{"password" => "tiny"})

      assert html =~ ~s(data-testid="account-error")
      assert html =~ ~s(data-testid="account-reset-form")
    end

    # The page must not offer a form it cannot submit: a dead link gets the
    # explanation, not an input that will fail on press.
    test "a dead link offers no form at all", %{conn: conn, reset_token: token} do
      {:ok, view, _html} = live(conn, ~p"/account/reset/#{token}")

      view
      |> element(~s([data-testid="account-reset-form"]))
      |> render_submit(%{"password" => "a-brand-new-password"})

      {:ok, _view, html} = live(conn, ~p"/account/reset/#{token}")

      html =
        html
        |> Floki.parse_document!()
        |> Floki.raw_html()

      refute html =~ ~s(data-testid="account-reset-form")
      assert html =~ ~s(data-testid="account-error")
    end
  end

  defp link(token), do: @link_prefix <> token

  defp set_email_and_capture(nickname, address) do
    :ok = NickEmail.set_email(nickname, address, &link/1)
    capture_token()
  end

  # The link is read out of the queued job: nothing here needs the message to
  # have been sent, only that it carries a link that works.
  defp capture_token do
    job = RetroHexChat.Repo.one!(from(j in Oban.Job, order_by: [desc: j.id], limit: 1))
    [_whole, token] = Regex.run(~r{#{@link_prefix}([A-Za-z0-9_\-\.]+)}, job.args["body"])
    token
  end
end
