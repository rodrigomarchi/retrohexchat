defmodule RetroHexChatWeb.Components.UI.Games.SoloLobbyTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.SoloLobby

  @moduletag :unit

  alias RetroHexChatWeb.GameCatalog

  # The same cards, under the same engines, as the public catalogue.
  test "renders the lobby as the catalogue's cards, under their engines" do
    groups = GameCatalog.arcade_groups()

    html =
      render_component(&solo_lobby/1,
        id: "arcade-lobby",
        groups: groups,
        session_status: "lobby",
        on_close: "arcade_leave"
      )

    document = Floki.parse_document!(html)

    for group <- groups, game <- group.games do
      assert [card] =
               Floki.find(
                 document,
                 ~s([data-testid="game-group-#{group.engine}"] a[data-testid="arcade-game-#{game.id}"][href="/?arcade=#{game.id}"])
               )

      # The engine is the h3; each game's name sits one level below it.
      assert card |> Floki.find("h4") |> Floki.text() |> String.trim() == game.name
      assert Floki.text(card) =~ game.tagline
      assert [_] = Floki.find(card, ~s(img[src="#{game.screenshot.path}"]))
    end

    assert Floki.find(document, ~s([data-testid^="solo-game-"])) == []
  end

  test "renders the selected game's sheet before starting" do
    {:ok, game} = GameCatalog.get_arcade("freedoom1")

    html =
      render_component(&solo_lobby/1,
        id: "arcade-lobby",
        groups: GameCatalog.arcade_groups(),
        session_status: "lobby",
        previewed_game: game,
        on_select_game: "arcade_select_game",
        on_back: "arcade_back",
        on_close: "arcade_leave"
      )

    document = Floki.parse_document!(html)
    text = Floki.text(document)

    assert [_] = Floki.find(document, ~s([data-testid="arcade-game-preview"]))
    assert text =~ game.name
    assert text =~ hd(game.about)
    assert text =~ hd(game.tips)
    assert [_] = Floki.find(document, ~s(img[src="#{game.screenshot.path}"]))
    assert [_ | _] = Floki.find(document, ~s([data-testid="game-controls"] kbd))

    assert [_] =
             Floki.find(
               document,
               ~s([data-testid="arcade-how-to-play"][href="/chat/help/feature-arcade-freedoom1"])
             )

    assert [_] =
             Floki.find(
               document,
               ~s([data-testid="solo-game-start-#{game.id}"][phx-click="arcade_select_game"])
             )

    assert [_] =
             Floki.find(
               document,
               ~s([data-testid="arcade-preview-back"][phx-click="arcade_back"])
             )
  end

  test "renders a back control while a game is running" do
    html =
      render_component(&solo_lobby/1,
        id: "arcade-lobby",
        groups: GameCatalog.arcade_groups(),
        session_status: "playing",
        game_name: "DOOM",
        game_id: "doom_shareware",
        on_back_to_launcher: "arcade_back_to_launcher",
        on_close: "arcade_leave"
      )

    document = Floki.parse_document!(html)

    assert [_] = Floki.find(document, ~s([data-testid="arcade-playing-state"]))

    assert [_] =
             Floki.find(
               document,
               ~s([data-testid="arcade-back"][phx-click="arcade_back_to_launcher"])
             )

    assert [_] = Floki.find(document, ~s([data-testid="solo-session-end"]))
  end

  test "says when a game started in the player's own time" do
    html =
      render_component(&solo_lobby/1,
        id: "arcade-lobby",
        groups: GameCatalog.arcade_groups(),
        session_status: "playing",
        game_name: "DOOM",
        game_id: "doom_shareware",
        game_started_at: "2026-10-22T15:04:05Z",
        timezone: "America/Sao_Paulo"
      )

    assert html =~ "12:04:05"
    refute html =~ "15:04:05"
  end
end
