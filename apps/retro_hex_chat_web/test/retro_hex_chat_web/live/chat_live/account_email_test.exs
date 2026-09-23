defmodule RetroHexChatWeb.ChatLive.AccountEmailTest do
  @moduledoc """
  The recovery address in the Account window.

  Two refusals carry the weight. The section is not drawn on a server that
  cannot send mail, because a field that saves an address nothing will ever use
  is a lie. And setting one requires having identified: an address is the way
  back into an account, so offering to set one to somebody who has not proved
  they own the nickname would be offering to hand the nickname over.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  import Ecto.Query

  @moduletag :liveview

  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.Services.RegisteredNick

  setup ctx do
    nick = "acce#{uid()}" |> String.slice(0, 16)
    NickServ.register(nick, "password123")
    NickServ.identify(nick, "password123")

    {:ok, view, _html} =
      ctx.conn |> chat_conn(nick, pre_identified: true) |> live(~p"/chat")

    render_click(view, "toolbar_action", %{"action" => "open_account_dialog"})

    %{view: view, nick: nick}
  end

  test "an identified owner can add an address", ctx do
    html = submit_email(ctx.view, "owner@example.com")

    assert html =~ ~s(data-testid="account-email-notice")
    assert reload(ctx.nick).email == "owner@example.com"
    assert reload(ctx.nick).email_verified_at == nil
  end

  test "the address is shown back, marked as waiting for the link", ctx do
    submit_email(ctx.view, "owner@example.com")

    html = render(ctx.view)

    assert html =~ "owner@example.com"
    assert html =~ ~s(data-testid="account-email-current")
  end

  test "something that is not an address is refused and nothing is queued", ctx do
    before = queued_count()

    html = submit_email(ctx.view, "not an address")

    assert html =~ ~s(data-testid="account-email-error")
    assert reload(ctx.nick).email == nil
    assert queued_count() == before
  end

  test "removing it clears the address and the pending link", ctx do
    submit_email(ctx.view, "owner@example.com")
    assert reload(ctx.nick).email_token_hash != nil

    ctx.view |> element(~s([data-testid="account-email-remove"])) |> render_click()

    row = reload(ctx.nick)
    assert row.email == nil
    assert row.email_token_hash == nil
  end

  # Absence, and why: the field would save an address nothing could ever use.
  test "a server that cannot send mail draws no address field", _ctx do
    original = Application.get_env(:retro_hex_chat, RetroHexChat.Mailer)
    Application.put_env(:retro_hex_chat, RetroHexChat.Mailer, adapter: nil)
    on_exit(fn -> Application.put_env(:retro_hex_chat, RetroHexChat.Mailer, original) end)

    nick = "nomail#{uid()}" |> String.slice(0, 16)
    NickServ.register(nick, "password123")
    NickServ.identify(nick, "password123")

    {:ok, view, _html} =
      build_conn() |> chat_conn(nick, pre_identified: true) |> live(~p"/chat")

    render_click(view, "toolbar_action", %{"action" => "open_account_dialog"})

    refute render(view) =~ ~s(data-testid="account-email-section")
  end

  # The other refusal: identity is checked again where the address is set, not
  # merely assumed from the section having been drawn.
  test "somebody who has not identified cannot set one", ctx do
    NickServ.remove_identified(ctx.nick)

    submit_email(ctx.view, "thief@example.com")

    assert reload(ctx.nick).email == nil
  end

  # The section is a LiveComponent the parent updates by message, so the HTML
  # `render_submit` hands back is the one from before that message. `render/1`
  # is a call queued behind it — synchronous, and nothing here sleeps.
  defp submit_email(view, address) do
    view
    |> element(~s(form[phx-submit="account_email_submit"]))
    |> render_submit(%{"email" => address})

    render(view)
  end

  defp reload(nickname), do: RetroHexChat.Repo.get_by(RegisteredNick, nickname: nickname)

  defp queued_count, do: RetroHexChat.Repo.aggregate(from(j in Oban.Job), :count)
end
