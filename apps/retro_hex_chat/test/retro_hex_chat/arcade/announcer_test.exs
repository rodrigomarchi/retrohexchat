defmodule RetroHexChat.Arcade.AnnouncerTest do
  use RetroHexChat.DataCase, async: false

  import RetroHexChat.Factory

  alias RetroHexChat.Arcade
  alias RetroHexChat.Arcade.{Announcer, Queries, SoloSessionServer}
  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Chat.Message
  alias RetroHexChat.Topics

  @moduletag :integration

  @rooms ["#doom-shareware", "#freedoom1", "#arcade"]

  setup do
    on_exit(fn -> Enum.each(@rooms, &stop_channel/1) end)
    ana = insert(:registered_nick, nickname: "ana")
    %{ana: ana}
  end

  defp stop_channel(name) do
    case ChannelRegistry.lookup(name) do
      {:ok, pid} -> ChannelSupervisor.stop_child(pid)
      {:error, :not_found} -> :ok
    end
  end

  # Press Play on `game_id` in a fresh session, as the in-app Arcade does.
  # The announcement runs after the reply; asking the session for its state
  # waits for it.
  defp start(player, game_id) do
    {:ok, %{token: token}} = Arcade.create_session(player.id)
    :ok = Arcade.join_session(token, player.id)
    :ok = Arcade.select_game(token, player.id, game_id)
    {:ok, _state} = SoloSessionServer.get_state(token)
    Queries.get_session_by_token(token)
  end

  test "a game somebody starts is said in its room and in #arcade, with a card", %{ana: ana} do
    insert_game_announcer(@rooms, name: "Pixel", nickname: "Pixel")
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.arcade_plays())

    session = start(ana, "doom_shareware")

    assert %Message{author_nickname: "Pixel", channel_name: "#doom-shareware", content: line} =
             Repo.get!(Message, session.channel_message_id)

    assert line == "ana started the game DOOM: Knee-Deep in the Dead"

    assert %Message{channel_name: "#arcade", content: ^line} =
             Repo.get!(Message, session.feed_message_id)

    channel_id = session.channel_message_id
    feed_id = session.feed_message_id

    assert %{
             ^channel_id => %{place: :channel, nickname: "ana", game_id: "doom_shareware"},
             ^feed_id => %{place: :feed}
           } = Arcade.play_cards_for_messages([channel_id, feed_id])

    assert_receive {:arcade_play_started, %{game_id: "doom_shareware"}}
  end

  test "starting the same game again within minutes is not said twice", %{ana: ana} do
    insert_game_announcer(@rooms, name: "Pixel", nickname: "Pixel")

    first = start(ana, "doom_shareware")
    again = start(ana, "doom_shareware")
    other = start(ana, "freedoom1")

    assert is_integer(first.channel_message_id)
    assert again.channel_message_id == nil
    assert again.feed_message_id == nil
    # Another game is news of its own.
    assert is_integer(other.channel_message_id)
  end

  test "a play said only in #arcade still counts against the next few minutes", %{ana: ana} do
    insert_game_announcer(["#arcade"], name: "Pixel", nickname: "Pixel")

    first = start(ana, "doom_shareware")
    again = start(ana, "doom_shareware")

    assert first.channel_message_id == nil
    assert is_integer(first.feed_message_id)
    assert again.feed_message_id == nil
  end

  test "a room with no announcer hears nothing, and the game still starts", %{ana: ana} do
    session = start(ana, "doom_shareware")

    assert session.status == "playing"
    assert session.channel_message_id == nil
    assert Repo.aggregate(Message, :count) == 0
  end

  test "a session with no game started says nothing" do
    assert :ok = Announcer.started(%Arcade.Schema.SoloSession{game_id: nil})
  end
end
