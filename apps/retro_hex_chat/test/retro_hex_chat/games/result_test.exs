defmodule RetroHexChat.Games.ResultTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Games.Result

  @moduletag :unit

  # One payload per spelling, copied from what the engines under
  # `assets/js/lib/games/*/engine.js` hand to `onGameEnd`.
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
