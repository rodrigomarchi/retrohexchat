defmodule RetroHexChat.Arcade.PlaysTest do
  use RetroHexChat.DataCase, async: true

  import RetroHexChat.Factory

  alias RetroHexChat.Arcade.{Plays, Queries}

  @moduletag :integration

  setup do
    %{
      ana: insert(:registered_nick, nickname: "ana"),
      beto: insert(:registered_nick, nickname: "beto")
    }
  end

  defp played(player, game_id, minutes_ago) do
    {:ok, session} =
      Queries.insert_session(%{
        token: "t#{System.unique_integer([:positive])}",
        creator_id: player.id,
        status: "playing",
        game_id: game_id,
        game_started_at: DateTime.add(DateTime.utc_now(), -minutes_ago, :minute)
      })

    session
  end

  test "the latest plays of a game name their players, newest first", %{ana: ana, beto: beto} do
    played(ana, "doom_shareware", 30)
    played(beto, "doom_shareware", 5)
    played(ana, "freedoom1", 1)

    # A session that never got as far as a game is no play.
    {:ok, _lobby} =
      Queries.insert_session(%{token: "lobby-only", creator_id: beto.id, status: "lobby"})

    assert [%{nickname: "beto"}, %{nickname: "ana"}] = Plays.recent("doom_shareware", 10)
  end

  test "who played most counts plays, and only since the date asked", %{ana: ana, beto: beto} do
    played(ana, "doom_shareware", 60 * 24 * 10)
    played(beto, "doom_shareware", 10)
    played(beto, "doom_shareware", 20)
    played(ana, "doom_shareware", 30)

    week_ago = DateTime.add(DateTime.utc_now(), -7, :day)

    assert [%{nickname: "beto", plays: 2}, %{nickname: "ana", plays: 1}] =
             Plays.most_played("doom_shareware", week_ago, 5)

    assert Plays.count_since("doom_shareware", week_ago) == 3
  end

  test "a day's plays and players, per game", %{ana: ana, beto: beto} do
    played(ana, "doom_shareware", 10)
    played(ana, "doom_shareware", 20)
    played(beto, "doom_shareware", 30)
    played(beto, "hacx", 40)

    since = DateTime.add(DateTime.utc_now(), -1, :day)

    assert %{
             "doom_shareware" => %{plays: 3, people: 2},
             "hacx" => %{plays: 1, people: 1}
           } = Plays.counts_between(since, DateTime.utc_now())
  end

  test "one player's record of a game", %{ana: ana} do
    assert %{plays: 0, last_at: nil} = Plays.player_record("doom_shareware", ana.id)

    played(ana, "doom_shareware", 50)
    latest = played(ana, "doom_shareware", 5)

    assert %{plays: 2, last_at: last_at} = Plays.player_record("doom_shareware", ana.id)
    assert DateTime.compare(last_at, latest.game_started_at) == :eq
  end
end
