defmodule RetroHexChatWeb.App.LobbyLive.Components.GameIslandTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.App.LobbyLive.Components.GameIsland

  @moduletag :unit

  test "id/0 is stable" do
    assert GameIsland.id() == "lobby-game"
  end

  test "prompts to connect before the lobby is connected" do
    html = render_component(GameIsland, id: GameIsland.id(), connected: false)

    refute html =~ ~s(data-testid="lobby-game-panel")
    assert html =~ "Connect to play"
  end

  test "lists the game catalog when connected and idle" do
    html = render_component(GameIsland, id: GameIsland.id(), connected: true)

    assert html =~ ~s(data-testid="lobby-game-panel")
    assert html =~ "Hex Pong"
  end

  test "shows the consent prompt for an incoming request" do
    html =
      render_component(GameIsland,
        id: GameIsland.id(),
        connected: true,
        action: {:request, %{game_id: "hex_pong", proposer_nick: "neo"}, false}
      )

    assert html =~ ~s(data-testid="lobby-game-consent")
    assert html =~ "neo"
  end

  test "shows the waiting state for an outgoing request" do
    html =
      render_component(GameIsland,
        id: GameIsland.id(),
        connected: true,
        peer_nick: "trinity",
        action: {:request, %{game_id: "hex_pong", proposer_nick: "neo"}, true}
      )

    refute html =~ ~s(data-testid="lobby-game-consent")
    assert html =~ "Waiting for"
    assert html =~ "trinity"
  end

  test "renders the in-progress state and canvas while playing" do
    html =
      render_component(GameIsland,
        id: GameIsland.id(),
        connected: true,
        action: {:playing, "hex_pong", true}
      )

    assert html =~ "Game in progress"
    assert html =~ ~s(id="lobby-game-canvas")
  end

  test "renders the final-score card when a game finishes" do
    html =
      render_component(GameIsland,
        id: GameIsland.id(),
        connected: true,
        action: {:result, %{"score" => %{"p1" => 11, "p2" => 7}, "winner" => 1}}
      )

    assert html =~ ~s(data-testid="lobby-game-result")
    assert html =~ "Final Score"
    assert html =~ "11"
    assert html =~ "7"
    # A fresh (non-host) viewer whose opponent (P1) won sees a loss.
    assert html =~ "You lose."
    refute html =~ ~s(id="lobby-game-canvas")
  end

  test "dismissing the result returns to the game catalog" do
    html =
      render_component(GameIsland,
        id: GameIsland.id(),
        connected: true,
        action: :dismiss_result
      )

    refute html =~ ~s(data-testid="lobby-game-result")
    assert html =~ ~s(data-testid="lobby-game-panel")
    assert html =~ "Hex Pong"
  end
end
