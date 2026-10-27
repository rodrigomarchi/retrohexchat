defmodule RetroHexChat.Games.ResultTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Games.Result

  @moduletag :unit

  # Every game now sends the nested score with a numeric winner
  # (`assets/js/lib/games/core/result.js`). The other spellings are what
  # older chunks still cached in a browser send, and are still read.
  describe "the one spelling every game sends" do
    test "reads as the same result as each older spelling it replaced" do
      for {game_id, older, one} <- [
            # Hex Frost and Hex Skiing, and a Raid guest: flat score1/score2.
            {"hex_frost", %{"score1" => 3, "score2" => 1, "winner" => 1},
             %{"score" => %{"p1" => 3, "p2" => 1}, "winner" => 1}},
            {"hex_skiing", %{"score1" => 0, "score2" => 2, "winner" => 2},
             %{"score" => %{"p1" => 0, "p2" => 2}, "winner" => 2}},
            {"hex_raid", %{"score1" => 120, "score2" => 80, "winner" => 1},
             %{"score" => %{"p1" => 120, "p2" => 80}, "winner" => 1}},
            # Hex Hockey: score_p1/score_p2 and a winner in words.
            {"hex_hockey",
             %{"winner" => "p2", "score_p1" => 1, "score_p2" => 3, "periods" => 3, "mode" => 0},
             %{"score" => %{"p1" => 1, "p2" => 3}, "winner" => 2}},
            {"hex_hockey_blitz", %{"winner" => "draw", "score_p1" => 2, "score_p2" => 2},
             %{"score" => %{"p1" => 2, "p2" => 2}, "winner" => 0}},
            # A dropped channel, which Skiing and Hockey called a draw in words.
            {"hex_skiing_escape",
             %{"winner" => "draw", "score_p1" => 1, "score_p2" => 0, "disconnected" => true},
             %{"score" => %{"p1" => 1, "p2" => 0}, "winner" => 0, "disconnected" => true}},
            {"hex_hockey",
             %{"winner" => "draw", "score_p1" => 2, "score_p2" => 1, "disconnected" => true},
             %{"score" => %{"p1" => 2, "p2" => 1}, "winner" => 0, "disconnected" => true}}
          ] do
        assert {:ok, _result} = read = Result.normalize(game_id, older)
        assert Result.normalize(game_id, one) == read, "#{game_id}: #{inspect(one)}"
      end
    end

    test "reads for every game in the catalogue" do
      for game_id <- Catalog.game_ids() do
        winner = if Catalog.ranking(game_id) == :coop, do: 0, else: 1
        payload = %{"score" => %{"p1" => 2, "p2" => 1}, "winner" => winner}

        # A one-player game keeps only its player's points.
        p2 = if Catalog.solo_only?(game_id), do: 0, else: 1

        assert {:ok, %Result{game_id: ^game_id, p1_score: 2, p2_score: ^p2}} =
                 Result.normalize(game_id, payload)
      end
    end
  end

  # One payload per spelling a browser may send.
  describe "normalize/2 reads every engine's spelling" do
    test "nested score with a numeric winner (pong, tanks, tennis, invaders…)" do
      assert {:ok, %Result{p1_score: 11, p2_score: 7, outcome: :p1, disconnected?: false}} =
               Result.normalize("hex_pong", %{"score" => %{"p1" => 11, "p2" => 7}, "winner" => 1})

      assert {:ok, %Result{outcome: :p2}} =
               Result.normalize("pixel_tanks", %{
                 "score" => %{"p1" => 0, "p2" => 2},
                 "winner" => 2
               })
    end

    test "flat score1/score2 (skiing, frost, a raid guest)" do
      assert {:ok, %Result{p1_score: 2, p2_score: 1, outcome: :p1}} =
               Result.normalize("hex_skiing", %{"score1" => 2, "score2" => 1, "winner" => 1})

      assert {:ok, %Result{outcome: :draw}} =
               Result.normalize("hex_frost", %{"score1" => 1, "score2" => 1, "winner" => 0})
    end

    test "hockey's score_p1/score_p2 with string winners" do
      payload = %{"winner" => "p2", "score_p1" => 1, "score_p2" => 3, "periods" => 3, "mode" => 0}

      assert {:ok, %Result{p1_score: 1, p2_score: 3, outcome: :p2}} =
               Result.normalize("hex_hockey", payload)

      assert {:ok, %Result{outcome: :draw}} =
               Result.normalize("hex_hockey_blitz", %{
                 "winner" => "draw",
                 "score_p1" => 2,
                 "score_p2" => 2
               })
    end

    test "Block Breakers says whether the pair won" do
      assert {:ok, %Result{outcome: :coop_win, p1_score: 4200}} =
               Result.normalize("block_breakers", %{
                 "score" => %{"p1" => 4200, "p2" => 4200},
                 "winner" => 0
               })

      assert {:ok, %Result{outcome: :coop_loss}} =
               Result.normalize("block_breakers", %{
                 "score" => %{"p1" => 300, "p2" => 300},
                 "winner" => -1
               })
    end

    test "co-op Invaders cannot tell a win from a loss, so it names nobody" do
      assert {:ok, %Result{outcome: :none, p1_score: 900, p2_score: 450}} =
               Result.normalize("hex_invaders_coop", %{
                 "score" => %{"p1" => 900, "p2" => 450},
                 "winner" => 0
               })
    end

    test "atom keys read the same as string keys" do
      assert {:ok, %Result{p1_score: 3, p2_score: 1, outcome: :p1}} =
               Result.normalize("hex_boxing", %{score: %{p1: 3, p2: 1}, winner: 1})
    end
  end

  describe "normalize/2 on a disconnect" do
    test "names nobody whatever the winner field says" do
      assert {:ok, %Result{outcome: :none, disconnected?: true, p1_score: 5}} =
               Result.normalize("hex_pong", %{
                 "score" => %{"p1" => 5, "p2" => 3},
                 "winner" => 0,
                 "disconnected" => true
               })

      assert {:ok, %Result{outcome: :none, disconnected?: true}} =
               Result.normalize("hex_hockey", %{
                 "winner" => "draw",
                 "score_p1" => 1,
                 "score_p2" => 0,
                 "disconnected" => true
               })
    end
  end

  # End pressed mid-match: the match as it stood. A versus match is decided by
  # its score, whatever a browser claims; points and co-op games name nobody.
  describe "normalize/2 on a match ended early" do
    test "a versus match goes to whoever leads, and a level score is a draw" do
      for {p1, p2, outcome} <- [{3, 2, :p1}, {2, 3, :p2}, {2, 2, :draw}],
          winner <- [nil, 1, 2, 0] do
        payload = %{"score" => %{"p1" => p1, "p2" => p2}, "ended_early" => true}
        payload = if winner, do: Map.put(payload, "winner", winner), else: payload

        assert {:ok,
                %Result{
                  outcome: ^outcome,
                  p1_score: ^p1,
                  p2_score: ^p2,
                  ended_early?: true,
                  disconnected?: false
                }} = Result.normalize("hex_pong", payload)
      end
    end

    test "a score game and a co-op game keep their points and name nobody" do
      payload = %{"score" => %{"p1" => 900, "p2" => 300}, "ended_early" => true}

      assert {:ok, %Result{outcome: :none, p1_score: 900, ended_early?: true}} =
               Result.normalize("hex_raid", payload)

      assert {:ok, %Result{outcome: :none, ended_early?: true}} =
               Result.normalize("block_breakers", Map.put(payload, "winner", 0))
    end

    test "a match played to its end is not one ended early" do
      assert {:ok, %Result{ended_early?: false}} =
               Result.normalize("hex_pong", %{"score" => %{"p1" => 3, "p2" => 1}, "winner" => 1})
    end
  end

  describe "normalize/2 for a one-player game" do
    test "keeps the points and names nobody" do
      assert {:ok, %Result{p1_score: 4200, p2_score: 0, outcome: :none}} =
               Result.normalize("hex_jungle", %{
                 "score" => %{"p1" => 4200, "p2" => 0},
                 "winner" => 0
               })
    end

    test "takes from the browser only the points: nobody else's score, no disconnect" do
      assert {:ok, %Result{p1_score: 4200, p2_score: 0, outcome: :none, disconnected?: false}} =
               Result.normalize("hex_jungle", %{
                 "score" => %{"p1" => 4200, "p2" => 900},
                 "disconnected" => true
               })
    end

    test "refuses more points than the jungle holds" do
      assert {:ok, %Result{p1_score: 114_000}} =
               Result.normalize("hex_jungle", %{"score" => %{"p1" => 114_000, "p2" => 0}})

      assert {:error, :implausible} =
               Result.normalize("hex_jungle", %{"score" => %{"p1" => 114_001, "p2" => 0}})
    end

    test "refuses more points than a table of solitaire can score, in either variant" do
      for id <- ~w(hex_solitaire hex_solitaire_draw3) do
        assert {:ok, %Result{p1_score: 24_078}} =
                 Result.normalize(id, %{"score" => %{"p1" => 24_078, "p2" => 0}})

        assert {:error, :implausible} =
                 Result.normalize(id, %{"score" => %{"p1" => 24_079, "p2" => 0}})
      end
    end

    test "refuses more points than a game of Spider can score, in every variant" do
      for id <- ~w(hex_spider hex_spider_2suits hex_spider_4suits) do
        assert {:ok, %Result{p1_score: 1_300}} =
                 Result.normalize(id, %{"score" => %{"p1" => 1_300, "p2" => 0}})

        assert {:error, :implausible} =
                 Result.normalize(id, %{"score" => %{"p1" => 1_301, "p2" => 0}})
      end
    end

    test "refuses more points than a minefield can score, at every level" do
      for id <- ~w(hex_mines hex_mines_intermediate hex_mines_expert) do
        assert {:ok, %Result{p1_score: 10_000}} =
                 Result.normalize(id, %{"score" => %{"p1" => 10_000, "p2" => 0}})

        assert {:error, :implausible} =
                 Result.normalize(id, %{"score" => %{"p1" => 10_001, "p2" => 0}})
      end
    end

    test "refuses more points than a Sudoku can score, at every level" do
      for id <- ~w(hex_sudoku hex_sudoku_medium hex_sudoku_hard) do
        assert {:ok, %Result{p1_score: 10_000}} =
                 Result.normalize(id, %{"score" => %{"p1" => 10_000, "p2" => 0}})

        assert {:error, :implausible} =
                 Result.normalize(id, %{"score" => %{"p1" => 10_001, "p2" => 0}})
      end
    end

    test "refuses more points than a table of FreeCell can score" do
      assert {:ok, %Result{p1_score: 23_853}} =
               Result.normalize("hex_freecell", %{"score" => %{"p1" => 23_853, "p2" => 0}})

      assert {:error, :implausible} =
               Result.normalize("hex_freecell", %{"score" => %{"p1" => 23_854, "p2" => 0}})
    end
  end

  describe "normalize/2 refuses" do
    test "a game outside the catalogue" do
      assert {:error, :unknown_game} =
               Result.normalize("doom", %{"score" => %{"p1" => 1, "p2" => 0}, "winner" => 1})
    end

    test "a missing, negative or non-numeric score" do
      assert {:error, :malformed} = Result.normalize("hex_pong", %{"winner" => 1})

      assert {:error, :malformed} =
               Result.normalize("hex_pong", %{"score" => %{"p1" => -1, "p2" => 0}, "winner" => 2})

      assert {:error, :malformed} =
               Result.normalize("hex_pong", %{"score" => %{"p1" => "11", "p2" => 0}})

      assert {:error, :malformed} = Result.normalize("hex_pong", "11-0")
    end

    test "a score no match of the game can reach" do
      assert {:error, :implausible} =
               Result.normalize("hex_pong", %{"score" => %{"p1" => 500, "p2" => 0}, "winner" => 1})

      assert {:ok, _result} =
               Result.normalize("hex_enduro", %{
                 "score" => %{"p1" => 125_000, "p2" => 98_000},
                 "winner" => 1
               })
    end

    test "a versus winner the score contradicts" do
      assert {:error, :implausible} =
               Result.normalize("hex_pong", %{"score" => %{"p1" => 0, "p2" => 10}, "winner" => 1})

      assert {:error, :implausible} =
               Result.normalize("hex_pong", %{"score" => %{"p1" => 10, "p2" => 0}, "winner" => 2})

      assert {:error, :implausible} =
               Result.normalize("hex_hockey", %{
                 "score_p1" => 3,
                 "score_p2" => 1,
                 "winner" => "draw"
               })

      # A level score may still have a winner, settled by what the score omits.
      assert {:ok, %{outcome: :p2}} =
               Result.normalize("hex_frost", %{"score1" => 2, "score2" => 2, "winner" => 2})

      # A score game's winner is not its scorer: Hex Invaders is lost by dying.
      assert {:ok, %{outcome: :p2}} =
               Result.normalize("hex_invaders", %{"score1" => 900, "score2" => 300, "winner" => 2})

      # A disconnect names nobody, whatever the score was.
      assert {:ok, %{outcome: :none}} =
               Result.normalize("hex_pong", %{
                 "score" => %{"p1" => 0, "p2" => 5},
                 "winner" => 1,
                 "disconnected" => true
               })
    end
  end

  test "decided?/1 is false only for a match that names nobody" do
    {:ok, won} =
      Result.normalize("hex_pong", %{"score" => %{"p1" => 11, "p2" => 4}, "winner" => 1})

    {:ok, dropped} =
      Result.normalize("hex_pong", %{
        "score" => %{"p1" => 2, "p2" => 4},
        "winner" => 0,
        "disconnected" => true
      })

    assert Result.decided?(won)
    refute Result.decided?(dropped)
  end
end
