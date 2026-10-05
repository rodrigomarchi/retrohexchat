defmodule RetroHexChatWeb.ChatLive.PubsubRoutingTest do
  @moduledoc """
  A message a handler knows how to show must reach it.

  `PubsubHandlers` routes by message shape and ends in a catch-all that passes
  anything unknown along. A handler in `ChannelState` without a route is
  therefore never called, and nothing else fails: the broadcast is still sent,
  so a test of the broadcast passes while the room is shown nothing.

  What a notice looks like on screen is the browser's to prove (PW21): it
  reaches the conversation through an async `send_update`, which a LiveView
  test must not assert on.
  """
  use ExUnit.Case, async: true

  @moduletag :unit

  @channel_state Path.expand(
                   "../../../../lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/channel_state.ex",
                   __DIR__
                 )
  @router Path.expand(
            "../../../../lib/retro_hex_chat_web/live/chat_live/pubsub_handlers.ex",
            __DIR__
          )

  test "every message ChannelState handles has a route to it" do
    handled = message_tags(@channel_state)
    routed = message_tags(@router)

    assert MapSet.difference(handled, routed) == MapSet.new(),
           "ChannelState handles messages PubsubHandlers never routes to it"
  end

  defp message_tags(path) do
    ~r/def handle_info\(\s*\{:([a-z_]+)/
    |> Regex.scan(File.read!(path))
    |> Enum.map(&List.last/1)
    |> MapSet.new()
  end
end
