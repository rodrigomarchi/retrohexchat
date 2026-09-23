defmodule RetroHexChatWeb.ConnectRecoveryTest do
  @moduledoc """
  "I forgot my password", and the two things it must never do.

  It must not appear on a server that cannot send mail — a control that can do
  nothing is worse than no control — and it must answer identically whatever
  nickname it is given, or it becomes a way to read the register one guess at a
  time.
  """
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Ecto.Query

  @moduletag :liveview

  alias RetroHexChat.Services.NickEmail
  alias RetroHexChat.Services.Queries

  setup do
    nick = "rec#{uid()}" |> String.slice(0, 16)
    {:ok, _} = Queries.insert_registered_nick(nick, "password123")
    %{nick: nick}
  end

  test "the password step offers recovery", %{conn: conn, nick: nick} do
    {:ok, view, _html} = live(conn, ~p"/connect")

    html = enter_nickname(view, nick)

    assert html =~ ~s(data-testid="forgot-password-btn")
  end

  test "asking for a link says the same thing whoever asked", %{conn: conn, nick: nick} do
    {:ok, view, _html} = live(conn, ~p"/connect")
    enter_nickname(view, nick)

    before = RetroHexChat.Repo.aggregate(from(j in Oban.Job), :count)
    html = view |> element(~s([data-testid="forgot-password-btn"])) |> render_click()

    assert html =~ ~s(data-testid="recovery-sent")
    # No address on this nickname, so nothing was queued — and the page says
    # exactly what it says for somebody who has one.
    assert RetroHexChat.Repo.aggregate(from(j in Oban.Job), :count) == before
  end

  # Asserted on what was stored rather than on the message: the mail leaves from
  # the LiveView's own process, so it never reaches this one's mailbox. What the
  # message says, and that its link works, is proved where it is built — in
  # `RetroHexChat.Services.NickEmailTest`.
  test "a nickname with a confirmed address gets a reset minted", %{conn: conn, nick: nick} do
    :ok = NickEmail.set_email(nick, "recover@example.com", &"https://example.test/a/#{&1}")
    job = RetroHexChat.Repo.one!(from(j in Oban.Job, order_by: [desc: j.id], limit: 1))
    [_whole, token] = Regex.run(~r{/a/([A-Za-z0-9_\-\.]+)}, job.args["body"])
    {:ok, ^nick} = NickEmail.verify_email(token)
    assert reload(nick).email_token_hash == nil

    {:ok, view, _html} = live(conn, ~p"/connect")
    enter_nickname(view, nick)
    view |> element(~s([data-testid="forgot-password-btn"])) |> render_click()

    assert reload(nick).email_token_hash != nil
  end

  # Absence, and the reason it matters: the button would be a dead end on a
  # self-hosted server that never configured a relay.
  test "a server that cannot send mail offers nothing", %{conn: conn, nick: nick} do
    original = Application.get_env(:retro_hex_chat, RetroHexChat.Mailer)
    Application.put_env(:retro_hex_chat, RetroHexChat.Mailer, adapter: nil)
    on_exit(fn -> Application.put_env(:retro_hex_chat, RetroHexChat.Mailer, original) end)

    {:ok, view, _html} = live(conn, ~p"/connect")

    html = enter_nickname(view, nick)

    refute html =~ ~s(data-testid="forgot-password-btn")
  end

  defp reload(nickname) do
    RetroHexChat.Repo.get_by(RetroHexChat.Services.RegisteredNick, nickname: nickname)
  end

  defp enter_nickname(view, nick) do
    view
    |> element(~s(form[phx-submit="connect"]))
    |> render_submit(%{"nickname" => nick})
  end
end
