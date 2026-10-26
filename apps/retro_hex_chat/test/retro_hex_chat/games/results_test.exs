defmodule RetroHexChat.Games.ResultsTest do
  # Recording a match between two people announces it in its game's channel,
  # which is a process of its own: not something an async test may share.
  use RetroHexChat.DataCase, async: false

  import RetroHexChat.Factory

  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Games.Results
  alias RetroHexChat.Games.Schema.GameResult
  alias RetroHexChat.Topics

  @moduletag :integration

  setup do
    on_exit(fn ->
      for name <- [Catalog.feed_channel() | Catalog.channel_names()],
          {:ok, pid} <- [ChannelRegistry.lookup(name)],
          do: ChannelSupervisor.stop_child(pid)
    end)

    ana = insert(:registered_nick, nickname: "ana")
    beto = insert(:registered_nick, nickname: "beto")
    %{ana: player(ana), beto: player(beto)}
  end

  defp player(nick), do: %{id: nick.id, nickname: nick.nickname}

  defp ago(ms), do: DateTime.add(DateTime.utc_now(), -ms, :millisecond)

  defp ai_match(player, game_id, payload, opts \\ []) do
    %{
      game_id: game_id,
      origin: "ai",
      difficulty: Keyword.get(opts, :difficulty, "normal"),
      p1: player,
      payload: payload,
      started_at: Keyword.get(opts, :started_at, ago(60_000))
    }
  end

  defp p2p_match(host, guest, game_id, payload, opts \\ []) do
    %{
      game_id: game_id,
      origin: "p2p",
      p1: host,
      p2: guest,
      payload: payload,
      lobby_token: Keyword.get(opts, :token, "tok-1"),
      started_at: Keyword.get(opts, :started_at, ago(90_000))
    }
  end

  defp pong(p1, p2, winner), do: %{"score" => %{"p1" => p1, "p2" => p2}, "winner" => winner}
  defp raid(p1, p2), do: %{"score" => %{"p1" => p1, "p2" => p2}, "winner" => 1}

  describe "record/1" do
    test "writes a match against the computer and announces it", %{ana: ana} do
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.game_results())

      assert {:ok, %GameResult{} = row} =
               Results.record(ai_match(ana, "hex_pong", pong(11, 7, 1), difficulty: "hard"))

      assert row.base_id == "hex_pong"
      assert row.outcome == "p1"
      assert row.difficulty == "hard"
      assert row.ranked
      assert row.p2_nickname == nil
      assert row.duration_ms >= 60_000

      assert_receive {:game_result_recorded, %GameResult{id: id}}
      assert id == row.id
    end

    test "writes a two-player match under its lobby session once", %{ana: ana, beto: beto} do
      started_at = ago(90_000)
      match = p2p_match(ana, beto, "hex_tennis_quick", pong(3, 1, 1), started_at: started_at)

      assert {:ok, row} = Results.record(match)
      assert row.base_id == "hex_tennis"
      assert row.p2_nickname == "beto"

      assert {:error, :already_recorded} = Results.record(match)
      assert Repo.aggregate(GameResult, :count) == 1
    end

    test "keeps a disconnect out of the rankings", %{ana: ana, beto: beto} do
      payload = Map.put(pong(4, 2, 0), "disconnected", true)
      assert {:ok, row} = Results.record(p2p_match(ana, beto, "hex_pong", payload))
      refute row.ranked
      assert row.outcome == "none"
    end

    test "refuses what no real match produces", %{ana: ana} do
      assert {:error, :too_short} =
               Results.record(ai_match(ana, "hex_pong", pong(11, 0, 1), started_at: ago(500)))

      assert {:error, :implausible} = Results.record(ai_match(ana, "hex_pong", pong(900, 0, 1)))
      assert {:error, :unknown_game} = Results.record(ai_match(ana, "doom", pong(1, 0, 1)))
      assert Repo.aggregate(GameResult, :count) == 0
    end

    test "marks a personal best only in a score game", %{ana: ana} do
      assert {:ok, %{personal_best: true}} =
               Results.record(ai_match(ana, "hex_raid", raid(500, 100)))

      assert {:ok, %{personal_best: false}} =
               Results.record(ai_match(ana, "hex_raid", raid(400, 100)))

      assert {:ok, %{personal_best: true}} =
               Results.record(ai_match(ana, "hex_raid", raid(800, 100)))

      # Another difficulty is another ladder.
      assert {:ok, %{personal_best: true}} =
               Results.record(ai_match(ana, "hex_raid", raid(100, 50), difficulty: "hard"))

      assert {:ok, %{personal_best: false}} =
               Results.record(ai_match(ana, "hex_pong", pong(11, 0, 1)))
    end

    test "writes a one-player match as solo, with no difficulty, and its best", %{ana: ana} do
      solo = fn points ->
        %{
          game_id: "hex_jungle",
          origin: "solo",
          p1: ana,
          payload: %{"score" => %{"p1" => points, "p2" => 0}, "winner" => 0},
          started_at: ago(60_000)
        }
      end

      assert {:ok, %{origin: "solo", difficulty: nil, ranked: true, personal_best: true} = row} =
               Results.record(solo.(4200))

      assert row.outcome == "none"
      assert {:ok, %{personal_best: false}} = Results.record(solo.(3000))
      assert {:ok, %{personal_best: true}} = Results.record(solo.(9000))
    end

    test "a solo match carries no difficulty, and a match against the computer always does" do
      base = %{
        game_id: "hex_jungle",
        base_id: "hex_jungle",
        p1_nickname: "ana",
        p1_score: 1,
        p2_score: 0,
        outcome: "none",
        ranked: true,
        personal_best: false,
        duration_ms: 1000,
        started_at: DateTime.utc_now(),
        finished_at: DateTime.utc_now()
      }

      assert GameResult.changeset(%GameResult{}, Map.put(base, :origin, "solo")).valid?

      refute GameResult.changeset(
               %GameResult{},
               Map.merge(base, %{origin: "solo", difficulty: "hard"})
             ).valid?

      refute GameResult.changeset(%GameResult{}, Map.put(base, :origin, "ai")).valid?
    end

    test "ranks a match ended early as it stood, a best score included", %{ana: ana} do
      early = fn p1, p2 -> %{"score" => %{"p1" => p1, "p2" => p2}, "ended_early" => true} end

      assert {:ok, %{ranked: true, outcome: "p1"}} =
               Results.record(ai_match(ana, "hex_pong", early.(4, 2)))

      assert {:ok, %{ranked: true, outcome: "none", personal_best: true}} =
               Results.record(ai_match(ana, "hex_raid", early.(700, 900)))
    end
  end

  describe "standings/2" do
    test "a versus game ranks wins, as host and as guest alike", %{ana: ana, beto: beto} do
      {:ok, _} = Results.record(p2p_match(ana, beto, "hex_pong", pong(11, 5, 1), token: "a"))
      {:ok, _} = Results.record(p2p_match(beto, ana, "hex_pong", pong(4, 11, 2), token: "b"))
      {:ok, _} = Results.record(p2p_match(beto, ana, "hex_pong", pong(11, 9, 1), token: "c"))

      assert [
               %{nickname: "ana", wins: 2, matches: 3},
               %{nickname: "beto", wins: 1, matches: 3}
             ] = Results.standings("hex_pong")
    end

    test "a score game ranks the best score, per difficulty", %{ana: ana, beto: beto} do
      {:ok, _} = Results.record(ai_match(ana, "hex_raid", raid(300, 0)))
      {:ok, _} = Results.record(ai_match(beto, "hex_raid", raid(700, 0)))
      {:ok, _} = Results.record(ai_match(ana, "hex_raid", raid(900, 0), difficulty: "hard"))

      assert [%{nickname: "beto", best: 700}, %{nickname: "ana", best: 300}] =
               Results.standings("hex_raid", origin: "ai", difficulty: "normal")

      assert [%{nickname: "ana", best: 900}] =
               Results.standings("hex_raid", origin: "ai", difficulty: "hard")
    end

    test "only counts what finished since a moment", %{ana: ana, beto: beto} do
      {:ok, _old} = Results.record(p2p_match(ana, beto, "hex_pong", pong(11, 2, 1), token: "old"))
      Repo.update_all(GameResult, set: [finished_at: ago(10 * 86_400_000)])
      {:ok, _} = Results.record(p2p_match(ana, beto, "hex_pong", pong(2, 11, 2), token: "new"))

      assert [%{nickname: "beto", wins: 1}, %{nickname: "ana", wins: 0}] =
               Results.standings("hex_pong", since: ago(86_400_000))
    end
  end

  describe "player_record/3" do
    test "a player's rating, matches by opponent and latest matches, private ones too",
         %{ana: ana, beto: beto} do
      {:ok, _} = Results.record(p2p_match(ana, beto, "hex_pong", pong(11, 7, 1), token: "rec-1"))

      {:ok, _} =
        Results.record(
          Map.put(
            p2p_match(beto, ana, "hex_pong", pong(11, 9, 1), token: "rec-2"),
            :public?,
            false
          )
        )

      {:ok, _} = Results.record(ai_match(ana, "hex_pong", pong(11, 3, 1)))

      record = Results.player_record("hex_pong", ana.id)

      assert %{rating: rating, matches: 2, wins: 1, losses: 1, draws: 0, rank: rank, players: 2} =
               record.rating

      assert is_integer(rating) and rank in [1, 2]
      assert %{matches: 2, wins: 1} = record.people
      assert %{matches: 1, wins: 1, best: 11} = record.computer
      assert length(record.recent) == 3
    end

    test "a score game has no rating, and a stranger to the game has nothing", %{ana: ana} do
      {:ok, _} = Results.record(ai_match(ana, "hex_raid", raid(900, 300)))

      assert %{rating: nil, people: nil, computer: %{best: 900}} =
               Results.player_record("hex_raid_blitz", ana.id)

      assert %{rating: nil, people: nil, computer: nil, recent: []} =
               Results.player_record("hex_pong", ana.id)
    end
  end

  describe "cards" do
    test "a card is found by the kind of line that announced it", %{ana: ana} do
      {:ok, row} = Results.record(ai_match(ana, "hex_pong", pong(11, 7, 1)))
      pm = insert(:private_message, sender_nickname: "ana", recipient_nickname: "beto")
      {:ok, _} = Results.attach_message(row, :private, pm.id)

      pm_id = pm.id

      assert %{^pm_id => %{outcome: :p1, p1_score: 11, p2_score: 7}} =
               Results.cards_for_messages(:private, [pm_id])

      assert Results.cards_for_messages(:channel, [pm.id]) == %{}
    end

    test "recent/2 covers every mode of the game, newest first", %{ana: ana} do
      {:ok, _} = Results.record(ai_match(ana, "hex_tennis", pong(6, 2, 1)))
      {:ok, _} = Results.record(ai_match(ana, "hex_tennis_quick", pong(1, 3, 2)))

      assert [%{game_id: "hex_tennis_quick"}, %{game_id: "hex_tennis"}] =
               Results.recent("hex_tennis")

      assert Results.count_since("hex_tennis", ago(3_600_000)) == 2
      assert Results.counts_since(ago(3_600_000)) == %{"hex_tennis" => 2}
    end
  end
end
