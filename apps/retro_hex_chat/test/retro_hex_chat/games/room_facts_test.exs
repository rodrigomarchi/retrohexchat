defmodule RetroHexChat.Games.RoomFactsTest do
  use RetroHexChat.DataCase, async: true

  import RetroHexChat.Factory

  alias RetroHexChat.Games.Results
  alias RetroHexChat.Games.RoomFacts

  @moduletag :integration

  setup do
    %{ana: player("ana"), beto: player("beto")}
  end

  defp player(nickname) do
    nick = insert(:registered_nick, nickname: nickname)
    %{id: nick.id, nickname: nickname}
  end

  defp pong(p1, p2, winner, ana, beto, token) do
    {:ok, _row} =
      Results.record(%{
        game_id: "hex_pong",
        origin: "p2p",
        p1: ana,
        p2: beto,
        lobby_token: token,
        payload: %{"score" => %{"p1" => p1, "p2" => p2}, "winner" => winner},
        started_at: DateTime.add(DateTime.utc_now(), -90, :second)
      })
  end

  describe "welcome/1" do
    test "tells what a game's room is about, from the game and its week" do
      assert [about, week] = RoomFacts.welcome("#hex-pong")
      assert about =~ "Hex Pong: Pong reimagined"
      assert week =~ "This week's challenge is"
      assert week =~ "Nobody leads it yet."
      assert week =~ "!ranking !challenge !recent !howto"
    end

    test "the feed names every game's room" do
      assert [about, latest] = RoomFacts.welcome("#retro-games")
      assert about =~ "#hex-pong"
      assert about =~ "#hex-hockey"
      assert latest == "No public match has been played yet."
    end

    test "any other room has nothing to say" do
      assert RoomFacts.welcome("#lobby") == []
      assert RoomFacts.intro("#lobby") == nil
      assert RoomFacts.answer("ranking", "#lobby") == :unknown
    end

    test "is English whatever the process speaks" do
      Gettext.put_locale(RetroHexChat.Gettext, "pt_BR")
      assert [_about, week] = RoomFacts.welcome("#hex-pong")
      assert week =~ "This week's challenge is"
    end
  end

  describe "answer/2" do
    test "ranks a versus game by wins against people", %{ana: ana, beto: beto} do
      pong(11, 3, 1, ana, beto, "t1")
      pong(11, 5, 1, ana, beto, "t2")
      pong(4, 11, 2, ana, beto, "t3")

      assert {:ok, ranking} = RoomFacts.answer("ranking", "#hex-pong")
      assert ranking == "Hex Pong — 1. ana (2 wins) · 2. beto (1 win)"
    end

    test "says the latest matches, newest first", %{ana: ana, beto: beto} do
      pong(11, 3, 1, ana, beto, "t1")

      assert {:ok, "ana beat beto 11 × 3 in Hex Pong"} = RoomFacts.answer("recent", "#hex-pong")

      assert {:ok, "Latest: ana beat beto 11 × 3 in Hex Pong"} =
               RoomFacts.answer("recent", "#retro-games")
    end

    test "with nothing played says so" do
      assert {:ok, "Hex Pong has no ranking yet. Win a match against another player to enter it."} =
               RoomFacts.answer("ranking", "#hex-pong")

      assert {:ok, "No public match of Hex Pong yet."} = RoomFacts.answer("recent", "#hex-pong")
    end

    test "tells how to play" do
      assert {:ok, "Hex Pong: Arrow keys or W/S to move paddle. Press Play" <> _} =
               RoomFacts.answer("howto", "#hex-pong")
    end

    test "tells how a game played alone is played, with nobody to find" do
      assert {:ok, howto} = RoomFacts.answer("howto", "#hex-jungle")
      assert howto =~ "Press Play under the topic to start it in your browser."
      refute howto =~ "partner"
    end

    test "the feed points a game's question at the game's room" do
      assert {:ok, "Each game also has its own room. #hex-pong" <> _} =
               RoomFacts.answer("ranking", "#retro-games")
    end

    test "anything else is not a question for it" do
      assert RoomFacts.answer("roll", "#hex-pong") == :unknown
    end
  end

  describe "an arcade game's room" do
    test "opens with what the game is, its keys and how to start it" do
      intro = RoomFacts.intro("#doom-shareware")
      assert intro =~ "DOOM: Knee-Deep in the Dead: The original Episode 1 of DOOM"
      assert intro =~ "DOOM: Knee-Deep in the Dead controls: WASD move, Mouse aim"
      assert intro =~ "Press Play under the topic to start it in your browser."
      refute intro =~ "!ranking"
      assert RoomFacts.room?("#doom-shareware")
    end

    test "tells whoever arrives the game and its keys, and answers !howto with them" do
      assert [about, keys] = RoomFacts.welcome("#scummvm-bass")
      assert about =~ "Beneath a Steel Sky:"
      assert keys =~ "Beneath a Steel Sky controls: "
      assert keys =~ "Press Play under the topic"

      assert {:ok, howto} = RoomFacts.answer("howto", "#scummvm-bass")
      assert howto =~ "Beneath a Steel Sky controls: "
    end

    test "has no score to ask about" do
      for question <- ~w(ranking challenge recent) do
        assert RoomFacts.answer(question, "#doom-shareware") == :unknown
      end
    end

    test "the arcade's own room is no game's room" do
      refute RoomFacts.room?("#arcade")
      assert RoomFacts.intro("#arcade") == nil
    end
  end
end
