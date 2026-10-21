defmodule RetroHexChat.Games.AnnouncerTest do
  use RetroHexChat.DataCase, async: false

  import RetroHexChat.Factory

  alias RetroHexChat.Bots.Bot
  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Chat.Message
  alias RetroHexChat.Games.Announcer
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Games.Results
  alias RetroHexChat.Games.Schema.GameResult
  alias RetroHexChat.Topics

  @moduletag :integration

  setup do
    Application.put_env(:retro_hex_chat, :game_result_min_duration_ms, 0)

    on_exit(fn ->
      Application.delete_env(:retro_hex_chat, :game_result_min_duration_ms)

      Enum.each(
        ["#hex-pong", "#hex-raid", "#hex-tennis", Catalog.feed_channel()],
        &stop_channel/1
      )
    end)

    insert_game_announcer(["#hex-pong", "#hex-raid", "#hex-tennis", Catalog.feed_channel()])

    ana = insert(:registered_nick, nickname: "ana")
    beto = insert(:registered_nick, nickname: "beto")
    %{ana: %{id: ana.id, nickname: "ana"}, beto: %{id: beto.id, nickname: "beto"}}
  end

  defp stop_channel(name) do
    case ChannelRegistry.lookup(name) do
      {:ok, pid} -> ChannelSupervisor.stop_child(pid)
      {:error, :not_found} -> :ok
    end
  end

  defp record(attrs) do
    {:ok, row} =
      attrs
      |> Map.put_new(:started_at, DateTime.add(DateTime.utc_now(), -60, :second))
      |> Results.record()

    Repo.reload!(row)
  end

  defp pong(p1, p2, winner), do: %{"score" => %{"p1" => p1, "p2" => p2}, "winner" => winner}

  test "a match between two people is said in its channel, the feed and their conversation",
       %{ana: ana, beto: beto} do
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.channel("#hex-pong"))

    row =
      record(%{
        game_id: "hex_pong",
        origin: "p2p",
        p1: ana,
        p2: beto,
        payload: pong(11, 9, 1),
        lobby_token: "tok-ann"
      })

    assert %Message{author_nickname: "Scoreboard", content: content, type: "message"} =
             Repo.get!(Message, row.channel_message_id)

    assert content == "ana beat beto 11 × 9 in Hex Pong"
    assert %Message{channel_name: "#retro-games"} = Repo.get!(Message, row.feed_message_id)
    assert is_integer(row.pm_message_id)

    # The card is attached before anybody is told about the line.
    assert_receive %{event: "new_message", payload: %{id: id, author: "Scoreboard"}}
    assert id == row.channel_message_id

    assert %{^id => %{place: :channel, outcome: :p1}} =
             Results.cards_for_messages(:channel, [id])
  end

  test "a routine match against the computer is kept out of the channels", %{ana: ana} do
    row =
      record(%{
        game_id: "hex_pong",
        origin: "ai",
        difficulty: "easy",
        p1: ana,
        payload: pong(3, 11, 2)
      })

    assert row.channel_message_id == nil
    assert row.feed_message_id == nil
    assert row.pm_message_id == nil
  end

  test "a personal best and a win on hard are news", %{ana: ana} do
    best =
      record(%{
        game_id: "hex_raid",
        origin: "ai",
        difficulty: "normal",
        p1: ana,
        payload: %{"score" => %{"p1" => 900, "p2" => 300}, "winner" => 1}
      })

    assert best.personal_best

    assert Repo.get!(Message, best.channel_message_id).content ==
             "ana set a personal best of 900 in Hex Raid"

    hard =
      record(%{
        game_id: "hex_pong",
        origin: "ai",
        difficulty: "hard",
        p1: ana,
        payload: pong(11, 4, 1)
      })

    assert Repo.get!(Message, hard.channel_message_id).content ==
             "ana beat the computer (hard) 11 × 4 in Hex Pong"
  end

  test "a match somebody left is never news", %{ana: ana, beto: beto} do
    refute Announcer.newsworthy?(%GameResult{origin: "p2p", ranked: false})

    row =
      record(%{
        game_id: "hex_pong",
        origin: "p2p",
        p1: ana,
        p2: beto,
        payload: Map.put(pong(2, 1, 0), "disconnected", true),
        lobby_token: "tok-left"
      })

    assert row.channel_message_id == nil

    assert Repo.get!(RetroHexChat.Chat.PrivateMessage, row.pm_message_id).content ==
             "ana vs beto in Hex Pong ended early, 2 × 1"
  end

  test "a match one player invited the other to stays between them", %{ana: ana, beto: beto} do
    row =
      record(%{
        game_id: "hex_pong",
        origin: "p2p",
        p1: ana,
        p2: beto,
        payload: pong(11, 9, 1),
        lobby_token: "tok-private",
        public?: false
      })

    refute row.public
    assert row.channel_message_id == nil
    assert row.feed_message_id == nil
    assert is_integer(row.pm_message_id)
    refute Enum.any?(Results.recent("hex_pong"), &(&1.result_id == row.id))
  end

  test "a player is news in a game's channel once every few minutes", %{ana: ana, beto: beto} do
    match = fn token, payload ->
      record(%{
        game_id: "hex_pong",
        origin: "p2p",
        p1: ana,
        p2: beto,
        payload: payload,
        lobby_token: token
      })
    end

    first = match.("tok-again-1", pong(11, 9, 1))
    rematch = match.("tok-again-2", pong(8, 11, 2))

    assert is_integer(first.channel_message_id)
    assert rematch.channel_message_id == nil
    assert rematch.feed_message_id == nil
    assert is_integer(rematch.pm_message_id)

    # Another game is other news.
    other =
      record(%{
        game_id: "hex_tennis",
        origin: "p2p",
        p1: ana,
        p2: beto,
        lobby_token: "tok-tennis",
        payload: %{"score" => %{"p1" => 3, "p2" => 1}, "winner" => 1}
      })

    assert is_integer(other.channel_message_id)
  end

  test "the announcing bot comes back to a channel that restarted without it", %{
    ana: ana,
    beto: beto
  } do
    stop_channel("#hex-pong")

    row =
      record(%{
        game_id: "hex_pong",
        origin: "p2p",
        p1: ana,
        p2: beto,
        payload: pong(11, 2, 1),
        lobby_token: "tok-back"
      })

    assert is_integer(row.channel_message_id)
  end

  test "a room whose bots do not announce games hears nothing, the players still do",
       %{ana: ana, beto: beto} do
    Repo.delete_all(Bot)

    row =
      record(%{
        game_id: "hex_pong",
        origin: "p2p",
        p1: ana,
        p2: beto,
        payload: pong(11, 4, 1),
        lobby_token: "tok-quiet"
      })

    assert row.channel_message_id == nil
    assert row.feed_message_id == nil
    assert is_integer(row.pm_message_id)
  end

  test "an announcer that turned the capability off is not asked", %{ana: ana, beto: beto} do
    Repo.update_all(Bot, set: [capabilities: %{"game" => %{"enabled" => false}}])

    row =
      record(%{
        game_id: "hex_pong",
        origin: "p2p",
        p1: ana,
        p2: beto,
        payload: pong(11, 5, 1),
        lobby_token: "tok-off"
      })

    assert row.channel_message_id == nil
  end
end
