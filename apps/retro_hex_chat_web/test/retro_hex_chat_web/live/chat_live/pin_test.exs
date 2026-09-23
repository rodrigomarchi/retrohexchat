defmodule RetroHexChatWeb.ChatLive.PinTest do
  @moduledoc """
  Pinning from the chat, and the refusal that matters.

  The permission is the channel's, not the command's: whether somebody may pin
  is a question about this channel right now, so it is asked where the
  membership lives. A regular member typing `/pin` must be refused there, not
  merely not offered the menu item.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.Pins
  alias RetroHexChat.Channels.Server

  setup ctx do
    owner = "Own#{uid()}"
    other = "Oth#{uid()}"
    channel = "#pin#{uid()}"

    {:ok, view, _html} = ctx.conn |> chat_conn(owner, pre_identified: true) |> live(~p"/chat")
    submit_command_sync(view, "/join #{channel}")
    {:ok, message} = Server.send_message(channel, owner, "the rules live here")

    %{view: view, owner: owner, other: other, channel: channel, message_id: message}
  end

  test "an operator keeps a line, and the bar counts it", ctx do
    submit_command_sync(ctx.view, "/pin #{ctx.message_id}")

    assert Pins.count(ctx.channel) == 1
    assert assigns(ctx.view).pinned_count == 1
  end

  test "unpinning removes it and the count follows", ctx do
    submit_command_sync(ctx.view, "/pin #{ctx.message_id}")
    submit_command_sync(ctx.view, "/unpin #{ctx.message_id}")

    assert Pins.count(ctx.channel) == 0
    assert assigns(ctx.view).pinned_count == 0
  end

  # The refusal. Joining a channel somebody else owns makes you a regular
  # member, and a regular member typing the command must be turned down by the
  # channel rather than by the absence of a button.
  test "a regular member is refused", ctx do
    {:ok, other_view, _html} =
      build_conn() |> chat_conn(ctx.other, pre_identified: true) |> live(~p"/chat")

    submit_command_sync(other_view, "/join #{ctx.channel}")
    submit_command_sync(other_view, "/pin #{ctx.message_id}")

    assert Pins.count(ctx.channel) == 0
  end

  test "a line from another channel is refused", ctx do
    elsewhere = "#else#{uid()}"
    submit_command_sync(ctx.view, "/join #{elsewhere}")
    {:ok, stranger} = Server.send_message(elsewhere, ctx.owner, "said somewhere else")

    submit_command_sync(ctx.view, "/switch #{ctx.channel}")
    render_click(ctx.view, "switch_channel", %{"channel" => ctx.channel})
    submit_command_sync(ctx.view, "/pin #{stranger}")

    assert Pins.count(ctx.channel) == 0
  end

  test "switching into a channel shows what it already keeps", ctx do
    {:ok, _pin} = Pins.pin(ctx.channel, ctx.message_id, ctx.owner)

    elsewhere = "#else#{uid()}"
    submit_command_sync(ctx.view, "/join #{elsewhere}")
    assert assigns(ctx.view).pinned_count == 0

    render_click(ctx.view, "switch_channel", %{"channel" => ctx.channel})

    assert assigns(ctx.view).pinned_count == 1
  end

  describe "the right-click menu" do
    test "pins from the menu, which is the only practical way in", ctx do
      render_click(ctx.view, "ctx_chat_pin_message", %{"message_id" => to_string(ctx.message_id)})

      assert Pins.count(ctx.channel) == 1
      assert assigns(ctx.view).pinned_count == 1
    end

    test "unpins from the menu", ctx do
      {:ok, _pin} = Pins.pin(ctx.channel, ctx.message_id, ctx.owner)

      render_click(ctx.view, "ctx_chat_unpin_message", %{
        "message_id" => to_string(ctx.message_id)
      })

      assert Pins.count(ctx.channel) == 0
    end

    # Hidden rather than disabled, and the refusal is the channel's: a regular
    # member who sends the event anyway is turned down where the pin is written.
    test "a regular member sending the event anyway is refused", ctx do
      {:ok, other_view, _html} =
        build_conn() |> chat_conn(ctx.other, pre_identified: true) |> live(~p"/chat")

      submit_command_sync(other_view, "/join #{ctx.channel}")

      render_click(other_view, "ctx_chat_pin_message", %{
        "message_id" => to_string(ctx.message_id)
      })

      assert Pins.count(ctx.channel) == 0
    end
  end

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns
end
