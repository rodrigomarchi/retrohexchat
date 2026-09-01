defmodule RetroHexChatWeb.ChatLive.ShareCardsTest do
  @moduledoc """
  What the live card costs, and when it stops costing it.

  The card in the conversation is the room it names right now, and two of the
  three kinds are free — the chat already hears a channel's conference
  broadcasts. The space is not: every step of every avatar is a roster message,
  so the subscription exists only while a card for that space is on screen.
  That is the assertion here, and it is the one the plan put in a table of its
  own because it is where this feature goes wrong by reflex.
  """
  use RetroHexChatWeb.ConnCase, async: false

  @moduletag :liveview

  alias Phoenix.Component
  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Topics
  alias RetroHexChatWeb.ChatLive.ShareCards

  defp socket(spaces \\ MapSet.new()) do
    Component.assign(%Socket{}, %{share_card_spaces: spaces})
  end

  # Subscribing twice to one topic delivers twice: `Phoenix.PubSub.subscribe`
  # is not idempotent, so "follow exactly this set" has to mean arithmetic on
  # the difference and never a re-subscribe of what is already followed.
  describe "watch_spaces/2" do
    test "follows a space when its card appears" do
      wanted = MapSet.new(["#retro"])
      socket = ShareCards.watch_spaces(socket(), wanted)

      assert socket.assigns.share_card_spaces == wanted

      Phoenix.PubSub.broadcast(RetroHexChat.PubSub, Topics.space_roster("#retro"), :ping)
      assert_receive :ping, 500
    end

    test "stops following when the last card for it goes" do
      socket = ShareCards.watch_spaces(socket(), MapSet.new(["#retro"]))
      socket = ShareCards.watch_spaces(socket, MapSet.new())

      assert socket.assigns.share_card_spaces == MapSet.new()

      Phoenix.PubSub.broadcast(RetroHexChat.PubSub, Topics.space_roster("#retro"), :ping)
      refute_receive :ping, 200
    end

    test "asking for the same set again subscribes nothing twice" do
      wanted = MapSet.new(["#retro"])

      socket()
      |> ShareCards.watch_spaces(wanted)
      |> ShareCards.watch_spaces(wanted)

      Phoenix.PubSub.broadcast(RetroHexChat.PubSub, Topics.space_roster("#retro"), :ping)

      assert_receive :ping, 500
      refute_receive :ping, 200
    end

    test "swapping one space for another follows only the new one" do
      socket = ShareCards.watch_spaces(socket(), MapSet.new(["#retro"]))
      ShareCards.watch_spaces(socket, MapSet.new(["#lobby"]))

      Phoenix.PubSub.broadcast(RetroHexChat.PubSub, Topics.space_roster("#retro"), :gone)
      refute_receive :gone, 200

      Phoenix.PubSub.broadcast(RetroHexChat.PubSub, Topics.space_roster("#lobby"), :here)
      assert_receive :here, 500
    end
  end

  describe "handle_info/2" do
    test "the viewport saying what it renders is what moves the subscriptions" do
      {:halt, socket} =
        ShareCards.handle_info({:share_card_spaces, MapSet.new(["#retro"])}, socket())

      assert socket.assigns.share_card_spaces == MapSet.new(["#retro"])
    end

    test "anything else is somebody else's" do
      assert {:cont, _socket} = ShareCards.handle_info(:something_else, socket())
    end
  end
end
