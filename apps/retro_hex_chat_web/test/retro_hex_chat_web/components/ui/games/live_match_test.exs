defmodule RetroHexChatWeb.Components.UI.LiveMatchTest do
  @moduledoc """
  A live match's players, each after the flag of their language — the
  languages carried by the match (`:player_locales`) or handed in by a page
  that already looked up every nickname it names.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.UI.LiveMatch

  @moduletag :unit

  @match %{token: "tok", game_id: "hex_pong", players: ["ana", "beto"], watchers: 0}

  defp flags(html) do
    html
    |> Floki.parse_fragment!()
    |> Floki.find(~s([data-testid="nick-flag"]))
    |> Enum.flat_map(&Floki.attribute(&1, "data-locale"))
  end

  test "the players are drawn with a flag before each name and set apart as a score is" do
    html =
      render_component(&LiveMatch.match_players/1,
        players: ["ana", nil, "beto"],
        locales: %{"ana" => "pt_BR", "beto" => "ja"}
      )

    assert flags(html) == ["pt_BR", "ja"]

    assert html |> Floki.parse_fragment!() |> Floki.text() |> String.split() |> Enum.join(" ") ==
             "ana × beto"
  end

  test "a link draws the languages its match carries" do
    match = Map.put(@match, :player_locales, %{"beto" => "de"})

    assert flags(render_component(&LiveMatch.live_match_link/1, match: match)) == ["de"]
  end

  test "a page's own lookup stands in for the match's" do
    html =
      render_component(&LiveMatch.live_match_link/1,
        match: @match,
        locales: %{"ana" => "fr"},
        new_tab: true
      )

    assert flags(html) == ["fr"]
  end

  test "a list of matches gets every player's language from one map" do
    other = %{@match | token: "tok2", players: ["cid", "ana"]}
    locales = %{"ana" => "pt_BR", "cid" => "ja", "zed" => "de"}

    assert [%{player_locales: %{"ana" => "pt_BR"}}, %{player_locales: second}] =
             LiveMatch.put_player_locales([@match, other], locales)

    assert second == %{"ana" => "pt_BR", "cid" => "ja"}
    assert LiveMatch.player_nicks([@match, other]) == ["ana", "beto", "cid"]
  end

  test "the line form stays plain text for the callers that need text" do
    assert LiveMatch.players_line(["ana", nil, "beto"]) == "ana × beto"
  end
end
