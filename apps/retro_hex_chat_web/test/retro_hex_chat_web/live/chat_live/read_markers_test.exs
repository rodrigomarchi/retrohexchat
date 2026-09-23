defmodule RetroHexChatWeb.ChatLive.ReadMarkersTest do
  @moduledoc """
  When the "you were here" marker moves.

  The whole feature turns on one rule: it must not move while you are reading.
  Advancing it as each message arrives is how this gets built, and it produces a
  divider that never appears — by the time anybody looks, the marker is already
  past everything new.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.Server

  setup ctx do
    nick = "Mark#{uid()}"
    other = "Other#{uid()}"
    {:ok, _} = register(nick)
    {:ok, _} = register(other)
    channel = "#mark#{uid()}"

    {:ok, view, _html} = ctx.conn |> chat_conn(nick) |> live(~p"/chat")
    submit_command_sync(view, "/join #{channel}")
    {:ok, _} = Server.join(channel, other)

    %{view: view, nick: nick, other: other, channel: channel}
  end

  # The one that matters. A marker that moves here is a divider nobody sees.
  test "a message arriving in the conversation on screen does not move it", ctx do
    {:ok, _} = Server.send_message(ctx.channel, ctx.other, "something new")

    assert markers(ctx.view) == %{}
  end

  test "coming back to the tab moves it to the newest line", ctx do
    {:ok, _} = Server.send_message(ctx.channel, ctx.other, "something new")
    render_click(ctx.view, "tab_focused", %{})

    assert markers(ctx.view)[ctx.channel]
  end

  test "leaving the conversation moves the marker of the one left behind", ctx do
    {:ok, _} = Server.send_message(ctx.channel, ctx.other, "something new")
    elsewhere = "#else#{uid()}"
    submit_command_sync(ctx.view, "/join #{elsewhere}")

    assert markers(ctx.view)[ctx.channel]
    refute markers(ctx.view)[elsewhere]
  end

  # Switching between two conversations already open is a different code path
  # from joining a new one, and both have to settle the marker of the one being
  # left.
  test "switching away from a conversation moves its marker too", ctx do
    elsewhere = "#else#{uid()}"
    submit_command_sync(ctx.view, "/join #{elsewhere}")
    render_click(ctx.view, "switch_channel", %{"channel" => ctx.channel})
    {:ok, _} = Server.send_message(ctx.channel, ctx.other, "something new")
    refute markers(ctx.view)[ctx.channel]

    render_click(ctx.view, "switch_channel", %{"channel" => elsewhere})

    assert markers(ctx.view)[ctx.channel]
  end

  # A first visit has no "new", so there is nothing to draw a rule above and no
  # button to offer.
  test "a conversation never opened before has no marker and no divider", ctx do
    fresh = "#fresh#{uid()}"
    submit_command_sync(ctx.view, "/join #{fresh}")

    refute markers(ctx.view)[fresh]
    assert boundary(ctx.view) == nil
  end

  test "coming back to a conversation with something new points the divider at it", ctx do
    {:ok, _} = Server.send_message(ctx.channel, ctx.other, "read this one")
    elsewhere = "#else#{uid()}"
    submit_command_sync(ctx.view, "/join #{elsewhere}")

    {:ok, _} = Server.send_message(ctx.channel, ctx.other, "this one is new")
    render_click(ctx.view, "switch_channel", %{"channel" => ctx.channel})

    assert boundary(ctx.view)
    assert render(ctx.view) =~ ~s(data-testid="conversation-toolbar-first-unread")
  end

  test "coming back with nothing new draws no divider and offers no jump", ctx do
    {:ok, _} = Server.send_message(ctx.channel, ctx.other, "read this one")
    elsewhere = "#else#{uid()}"
    submit_command_sync(ctx.view, "/join #{elsewhere}")
    render_click(ctx.view, "switch_channel", %{"channel" => ctx.channel})

    assert boundary(ctx.view) == nil
    refute render(ctx.view) =~ ~s(data-testid="conversation-toolbar-first-unread")
  end

  defp markers(view), do: :sys.get_state(view.pid).socket.assigns.read_markers
  defp boundary(view), do: :sys.get_state(view.pid).socket.assigns.unread_boundary_id

  defp register(nickname) do
    RetroHexChat.Repo.insert(%RetroHexChat.Services.RegisteredNick{
      nickname: nickname,
      password_hash: "x",
      registered_at: DateTime.utc_now(),
      last_seen_at: DateTime.utc_now()
    })
  end
end
