defmodule RetroHexChatWeb.ChatLive.RetroGamesEventsTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChatWeb.Components.UI.MenuBarApp

  defp retro_games(view), do: :sys.get_state(view.pid).socket.assigns.retro_games

  describe "open_retro_games" do
    test "opens the always-mounted Retro Games window for a guest", %{conn: conn} do
      nick = "retro#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "toolbar_action", %{"action" => "open_retro_games"})

      assert_push_event(view, "window_command", %{action: "open", id: "retro-games"})
      assert retro_games(view).status == "library"
      assert render(view) =~ ~s(data-testid="retro-games-window")
    end

    test "a game id opens the window with that game loaded", %{conn: conn} do
      nick = "retg#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "toolbar_action", %{
        "action" => "open_retro_games",
        "game-id" => "hex_pong"
      })

      assert_push_event(view, "window_command", %{action: "open", id: "retro-games"})
      assert render(view) =~ ~s(data-testid="retro-game-session-hex_pong")
      assert %{status: "ready", selected_game: %{id: "hex_pong"}} = retro_games(view)
    end

    test "an invalid game id leaves the launcher visible", %{conn: conn} do
      nick = "reti#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "toolbar_action", %{
        "action" => "open_retro_games",
        "game-id" => "not_a_retro_game"
      })

      assert_push_event(view, "window_command", %{action: "open", id: "retro-games"})
      assert render(view) =~ ~s(data-testid="retro-games-library")
      assert %{status: "library", selected_game: nil} = retro_games(view)
    end
  end

  describe "Games menu" do
    test "shows Retro Games as a single launcher beside the WASM Arcade entry" do
      document =
        render_component(&MenuBarApp.menu_bar_app/1,
          connected: true,
          arcade_available: false,
          on_action: "toolbar_action"
        )
        |> Floki.parse_document!()

      assert [_ | _] = Floki.find(document, ~s([data-testid="menu-retro-games"]))
      assert [_ | _] = Floki.find(document, ~s([data-testid="context-menu-item-open_arcade"]))
      assert Floki.find(document, ~s([data-testid^="menu-retro-game-"])) == []
    end
  end

  describe "island interactions" do
    test "selects Hex Pong and starts a ready solo canvas", %{conn: conn} do
      nick = "rets#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "toolbar_action", %{"action" => "open_retro_games"})
      render_click(element(view, ~s([data-testid="retro-game-hex_pong"])))

      html = render(view)
      assert html =~ ~s(phx-hook="RetroGameCanvasHook")
      assert html =~ ~s(data-game-id="hex_pong")
      assert %{status: "ready", selected_game: %{id: "hex_pong"}} = retro_games(view)
    end

    test "selects Light Trails and starts a ready solo canvas", %{conn: conn} do
      nick = "retl#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "toolbar_action", %{"action" => "open_retro_games"})
      render_click(element(view, ~s([data-testid="retro-game-light_trails"])))

      html = render(view)
      assert html =~ ~s(phx-hook="RetroGameCanvasHook")
      assert html =~ ~s(data-game-id="light_trails")
      assert %{status: "ready", selected_game: %{id: "light_trails"}} = retro_games(view)
    end

    test "selects Hex Outlaw and starts a ready solo canvas", %{conn: conn} do
      nick = "reto#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "toolbar_action", %{"action" => "open_retro_games"})
      render_click(element(view, ~s([data-testid="retro-game-hex_outlaw_ricochet"])))

      html = render(view)
      assert html =~ ~s(phx-hook="RetroGameCanvasHook")
      assert html =~ ~s(data-game-id="hex_outlaw_ricochet")
      assert %{status: "ready", selected_game: %{id: "hex_outlaw_ricochet"}} = retro_games(view)
    end

    test "does not emit the begin event before the canvas reports ready", %{conn: conn} do
      nick = "retw#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "toolbar_action", %{
        "action" => "open_retro_games",
        "game-id" => "hex_pong"
      })

      html = render(view)
      assert html =~ ~s(data-testid="retro-game-start-disabled")
    end

    test "starts the selected game after the canvas is ready", %{conn: conn} do
      nick = "retr#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "toolbar_action", %{
        "action" => "open_retro_games",
        "game-id" => "hex_pong"
      })

      render_hook(view, "retro_game_canvas_ready", %{"game_id" => "hex_pong"})
      render(view)
      render_click(element(view, ~s([data-testid="retro-game-start-ai"])))

      assert_push_event(view, "retro_game_begin", %{game_id: "hex_pong", difficulty: "normal"})
      render(view)
      assert %{status: "playing", selected_game: %{id: "hex_pong"}} = retro_games(view)
    end
  end
end
