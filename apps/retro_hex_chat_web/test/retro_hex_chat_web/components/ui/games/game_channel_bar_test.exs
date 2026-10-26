defmodule RetroHexChatWeb.Components.UI.GameChannelBarTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.GameChannelBar

  @moduletag :unit

  test "a game's channel offers the game, a seat and the game's home" do
    html = render_component(&game_channel_bar/1, channel: "#hex-pong")
    document = Floki.parse_document!(html)

    assert [_] =
             Floki.find(document, ~s([data-testid="game-channel-bar"][data-game-id="hex_pong"]))

    assert Floki.text(document) =~ "Hex Pong"

    assert [play] = Floki.find(document, ~s([data-testid="game-channel-play"]))
    assert Floki.attribute(play, "href") == ["/play/hex_pong"]

    assert [lfg] = Floki.find(document, ~s([data-testid="game-channel-lfg"]))
    assert Floki.attribute(lfg, "phx-click") == ["game_lfg"]

    # The game's name leads to its home, a page of the desktop: opened over
    # the chat, never in another tab.
    assert [home] = Floki.find(document, ~s([data-testid="game-channel-home"]))
    assert Floki.attribute(home, "href") == ["/games/hex-pong"]
    assert Floki.attribute(home, "data-phx-link") == ["patch"]
    assert Floki.attribute(home, "target") == []
  end

  test "a match of its game being played in the open is offered to watch" do
    live = [
      %{token: "pong-tok", game_id: "hex_pong", players: ["cid", "dora"], watchers: 4},
      %{token: "tennis-tok", game_id: "hex_tennis_quick", players: ["ana", "beto"], watchers: 2}
    ]

    document =
      render_component(&game_channel_bar/1, channel: "#hex-tennis", live_matches: live)
      |> Floki.parse_document!()

    # The match of a mode of the game counts as the game's.
    assert [link] = Floki.find(document, ~s([data-testid="live-match-link"]))
    assert Floki.attribute(link, "href") == ["/watch/tennis-tok"]
    assert link |> Floki.text() |> String.split() |> Enum.join(" ") =~ "ana × beto"
    # No count the strip would leave stale.
    refute Floki.text(link) =~ "watching"

    refute render_component(&game_channel_bar/1, channel: "#hex-pong", live_matches: []) =~
             "live-match-link"
  end

  test "each player of the offered match carries the flag of their language" do
    live = [
      %{
        token: "tennis-tok",
        game_id: "hex_tennis",
        players: ["ana", "beto"],
        watchers: 0,
        player_locales: %{"ana" => "pt_BR"}
      }
    ]

    players =
      render_component(&game_channel_bar/1, channel: "#hex-tennis", live_matches: live)
      |> Floki.parse_document!()
      |> Floki.find(~s([data-testid="live-match-link"] [data-testid="match-player"]))

    assert [ana, beto] = players

    assert ana |> Floki.find(~s([data-testid="nick-flag"])) |> Floki.attribute("data-locale") ==
             ["pt_BR"]

    assert Floki.find(beto, ~s([data-testid="nick-flag"])) == []
  end

  test "any other channel gets nothing" do
    refute render_component(&game_channel_bar/1, channel: "#lobby") =~ "game-channel-bar"
    refute render_component(&game_channel_bar/1, channel: nil) =~ "game-channel-bar"
  end

  test "an arcade game's channel offers the game itself, and nobody to play with" do
    document =
      render_component(&game_channel_bar/1, channel: "#doom-shareware") |> Floki.parse_document!()

    assert [_] =
             Floki.find(
               document,
               ~s([data-testid="game-channel-bar"][data-game-id="doom_shareware"])
             )

    assert Floki.text(document) =~ "DOOM: Knee-Deep in the Dead"

    assert [home] = Floki.find(document, ~s([data-testid="game-channel-home"]))
    assert Floki.attribute(home, "href") == ["/games/doom-shareware"]

    # Play opens the in-app Arcade on the game, as the Games menu does.
    assert [play] = Floki.find(document, ~s([data-testid="game-channel-play"]))
    assert Floki.attribute(play, "phx-click") == ["open_arcade"]
    assert Floki.attribute(play, "phx-value-game-id") == ["doom_shareware"]

    assert Floki.find(document, ~s([data-testid="game-channel-lfg"])) == []
    assert render_component(&game_channel_bar/1, channel: "#arcade") == ""
  end

  test "a game played alone offers the game, and no seat" do
    document =
      render_component(&game_channel_bar/1, channel: "#hex-jungle") |> Floki.parse_document!()

    assert [_] = Floki.find(document, ~s([data-testid="game-channel-play"]))
    assert Floki.find(document, ~s([data-testid="game-channel-lfg"])) == []
  end
end
