defmodule RetroHexChatWeb.P2PLive.Components.P2PGameIslandTest do
  use RetroHexChatWeb.ConnCase, async: true

  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Games.Result

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.UI.Lobby.GamePanel
  alias RetroHexChatWeb.P2PLive.Components.P2PGameIsland

  @moduletag :unit

  test "prompts to connect before the lobby is connected" do
    html = render_component(P2PGameIsland, id: P2PGameIsland.id(), connected: false)

    refute html =~ ~s(data-testid="lobby-game-panel")
    assert html =~ "Connect to play"
  end

  # A match others may watch says how many are, and hands over its address; a
  # private one says nothing about watching at all.
  test "a match played in the open says who is watching, and how to share it" do
    panel = fn watch_url ->
      render_component(&GamePanel.game_panel/1,
        connected: true,
        game: %{status: "playing", game_id: "hex_pong", is_host: true},
        game_request: nil,
        game_outgoing: false,
        games: Catalog.list_games(),
        peer_nick: "trinity",
        watchers: 2,
        watch_url: watch_url,
        menu_open: true
      )
    end

    html = panel.("https://example.test/watch/tok")
    assert html =~ ~s(data-testid="lobby-game-watchers")
    assert html =~ "2 watching"
    assert html =~ ~s(data-copy-text="https://example.test/watch/tok")

    refute panel.(nil) =~ "lobby-game-watchers"
  end

  # A match is played on its stage, as every Retro Game is: nothing over the
  # game but the corner key and, on a touch screen, the pad; the menu (Esc or
  # the key) holds Continue, End game and the whole screen, and the match goes
  # on under it.
  test "a running match has its stage, and its menu only when asked" do
    panel = fn menu_open ->
      render_component(&GamePanel.game_panel/1,
        connected: true,
        game: %{status: "playing", game_id: "hex_pong", is_host: true},
        game_request: nil,
        game_outgoing: false,
        games: Catalog.list_games(),
        peer_nick: "trinity",
        menu_open: menu_open
      )
      |> Floki.parse_document!()
    end

    running = panel.(false)
    assert [_] = Floki.find(running, ~s([data-testid="lobby-game-stage"] #lobby-game-canvas))
    assert [_] = Floki.find(running, ~s([data-testid="game-stage-menu-key"]))
    assert [_] = Floki.find(running, ~s([data-testid="retro-game-pad"]))
    assert Floki.find(running, ~s([data-testid="lobby-game-end"])) == []
    assert Floki.find(running, ~s([data-testid="lobby-game-panel"])) == []

    held = panel.(true)
    assert [_] = Floki.find(held, ~s([data-testid="lobby-game-resume"]))
    assert [_] = Floki.find(held, ~s([data-testid="lobby-game-end"]))
    assert [_] = Floki.find(held, ~s([data-testid="game-stage-fullscreen"]))
    assert Floki.find(held, ~s([data-testid="game-stage-menu-key"])) == []
  end

  test "lists the game catalog when connected and idle" do
    html = render_component(P2PGameIsland, id: P2PGameIsland.id(), connected: true)

    assert html =~ ~s(data-testid="lobby-game-panel")
    assert html =~ ~s(data-testid="p2p-games-catalog")
    assert html =~ "Hex Pong"
  end

  test "offers only the games two people play" do
    html = render_component(P2PGameIsland, id: P2PGameIsland.id(), connected: true)
    refute html =~ "Hex Jungle"
  end

  test "shows the consent prompt for an incoming request" do
    html =
      render_component(P2PGameIsland,
        id: P2PGameIsland.id(),
        connected: true,
        action: {:request, %{game_id: "hex_pong", proposer_nick: "neo"}, false}
      )

    assert html =~ ~s(data-testid="lobby-game-consent")
    assert html =~ "neo"
    assert html =~ "wants to play"
    assert html =~ "Accept"
    assert html =~ "Decline"
    refute html =~ ~s(data-testid="p2p-games-catalog")
  end

  test "shows the waiting state for an outgoing request" do
    html =
      render_component(P2PGameIsland,
        id: P2PGameIsland.id(),
        connected: true,
        peer_nick: "trinity",
        action: {:request, %{game_id: "hex_pong", proposer_nick: "neo"}, true}
      )

    refute html =~ ~s(data-testid="lobby-game-consent")
    assert html =~ ~s(data-testid="p2p-games-waiting")
    assert html =~ "Waiting for"
    assert html =~ "trinity"
    assert html =~ "Cancel"
    refute html =~ ~s(data-testid="p2p-games-catalog")
  end

  test "a game that starts is on its stage, with nothing over it" do
    html =
      render_component(P2PGameIsland,
        id: P2PGameIsland.id(),
        connected: true,
        action: {:playing, "hex_pong", true}
      )

    assert html =~ ~s(id="lobby-game-canvas")
    assert html =~ ~s(data-testid="game-stage-menu-key")
    refute html =~ "Game in progress"
  end

  test "renders the final-score card when a game finishes" do
    html =
      render_component(P2PGameIsland,
        id: P2PGameIsland.id(),
        connected: true,
        action: {:result, %Result{game_id: "hex_pong", p1_score: 11, p2_score: 7, outcome: :p1}}
      )

    assert html =~ ~s(data-testid="lobby-game-result")
    assert html =~ "Final Score"
    assert html =~ "11"
    assert html =~ "7"
    # A fresh (non-host) viewer whose opponent (P1) won sees a loss.
    assert html =~ "You lose."
    assert html =~ ~s(data-testid="lobby-game-rematch")
    refute html =~ ~s(id="lobby-game-canvas")
  end

  test "a draw and a co-op board read in words, whatever the engine sent" do
    for {outcome, words} <- [draw: "Draw.", coop_win: "Cleared together!", none: "Match over."] do
      html =
        render_component(P2PGameIsland,
          id: P2PGameIsland.id(),
          connected: true,
          action:
            {:result, %Result{game_id: "hex_pong", p1_score: 3, p2_score: 3, outcome: outcome}}
        )

      assert html =~ words
    end
  end

  test "dismissing the result returns to the game catalog" do
    html =
      render_component(P2PGameIsland,
        id: P2PGameIsland.id(),
        connected: true,
        action: :dismiss_result
      )

    refute html =~ ~s(data-testid="lobby-game-result")
    assert html =~ ~s(data-testid="lobby-game-panel")
    assert html =~ "Hex Pong"
  end
end
