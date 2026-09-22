defmodule RetroHexChatWeb.ChatLive.ChannelInviteEventsTest do
  @moduledoc """
  Copying a channel's invite link from the conversations menu.

  The link is the one object in the product made to leave it, so what matters
  here is that the address handed to the clipboard is the public one and that
  the policy refusing a stranger is the same policy the domain enforces.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.ShareLinks

  setup ctx do
    nick = "Inviter#{uid()}"
    {:ok, _} = register(nick)
    channel = "#invch#{uid()}"

    {:ok, view, _html} = ctx.conn |> chat_conn(nick) |> live(~p"/chat")
    submit_command_sync(view, "/join #{channel}")

    %{view: view, nick: nick, channel: channel}
  end

  test "copies a public /join address for the channel", ctx do
    render_click(ctx.view, "ctx_conversations_copy_invite", %{"channel" => ctx.channel})

    assert_push_event(ctx.view, "clipboard_copy", %{text: text})
    assert text =~ "/join/"

    slug = text |> String.split("/join/") |> List.last()
    assert {:ok, %{kind: "channel", target: %{"channel" => name}}} = ShareLinks.resolve(slug)
    assert name == ctx.channel
  end

  # Minting is idempotent per {kind, target, creator}: asking twice must hand
  # back the address already in circulation, not put a second one out there.
  test "asking twice hands back the same address", ctx do
    render_click(ctx.view, "ctx_conversations_copy_invite", %{"channel" => ctx.channel})
    assert_push_event(ctx.view, "clipboard_copy", %{text: first})

    render_click(ctx.view, "ctx_conversations_copy_invite", %{"channel" => ctx.channel})
    assert_push_event(ctx.view, "clipboard_copy", %{text: second})

    assert first == second
  end

  test "a channel the person is not in mints nothing", ctx do
    render_click(ctx.view, "ctx_conversations_copy_invite", %{"channel" => "#somewhereelse"})

    refute_push_event(ctx.view, "clipboard_copy", %{})
  end

  defp register(nickname) do
    RetroHexChat.Repo.insert(%RetroHexChat.Services.RegisteredNick{
      nickname: nickname,
      password_hash: "x",
      registered_at: DateTime.utc_now(),
      last_seen_at: DateTime.utc_now()
    })
  end
end
