defmodule RetroHexChat.Games.RatingsTest do
  use RetroHexChat.DataCase, async: true

  import RetroHexChat.Factory

  alias RetroHexChat.Games.Ratings
  alias RetroHexChat.Games.Schema.GameResult

  @moduletag :integration

  setup do
    %{
      ana: insert(:registered_nick, nickname: "ana"),
      beto: insert(:registered_nick, nickname: "beto")
    }
  end

  defp match(ana, beto, attrs) do
    struct(
      %GameResult{
        game_id: "hex_pong",
        base_id: "hex_pong",
        origin: "p2p",
        ranked: true,
        p1_id: ana.id,
        p2_id: beto.id,
        outcome: "p1"
      },
      attrs
    )
  end

  test "a win moves both ratings by the same amount, the other way", %{ana: ana, beto: beto} do
    :ok = Ratings.apply_result(match(ana, beto, %{}))

    assert [%{nickname: "ana", rating: 1216, matches: 1}, %{nickname: "beto", rating: 1184}] =
             Ratings.top("hex_pong")
  end

  test "beating somebody better is worth more", %{ana: ana, beto: beto} do
    :ok = Ratings.apply_result(match(ana, beto, %{}))
    :ok = Ratings.apply_result(match(ana, beto, %{outcome: "p2"}))

    # Beto, the lower-rated, won the second: he gains more than the 16 he lost.
    assert [%{nickname: "beto", rating: beto_rating}, %{nickname: "ana", rating: ana_rating}] =
             Ratings.top("hex_pong")

    assert beto_rating > 1200
    assert ana_rating + beto_rating == 2400
  end

  test "modes share their game's rating, and a draw between equals moves nothing", ctx do
    :ok =
      Ratings.apply_result(
        match(ctx.ana, ctx.beto, %{
          game_id: "hex_tennis_quick",
          base_id: "hex_tennis",
          outcome: "draw"
        })
      )

    assert [%{rating: 1200, matches: 1}, %{rating: 1200, matches: 1}] = Ratings.top("hex_tennis")
  end

  test "the computer, a match somebody left and a score game rate nobody", ctx do
    :ok = Ratings.apply_result(match(ctx.ana, ctx.beto, %{origin: "ai", p2_id: nil}))
    :ok = Ratings.apply_result(match(ctx.ana, ctx.beto, %{ranked: false}))

    :ok =
      Ratings.apply_result(match(ctx.ana, ctx.beto, %{game_id: "hex_raid", base_id: "hex_raid"}))

    assert Ratings.top("hex_pong") == []
    assert Ratings.top("hex_raid") == []
  end
end
