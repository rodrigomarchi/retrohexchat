defmodule RetroHexChatWeb.ChatLive.ArcadeSessionEventsTest do
  @moduledoc """
  In-chat solo arcade flow: the Arcade's folders are browsed without a
  session; a game's card opens the managed window on its sheet and creates a
  solo session, starting from the sheet drives the domain, and Back or leaving
  closes it — Back returning to the game's category folder. Asserts on synchronous LiveView state
  (`:sys.get_state`) and persisted domain rows — never on async broadcasts.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Arcade
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChatWeb.Components.UI.StartMenuApp
  alias RetroHexChatWeb.GameCatalog

  defp register(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> RetroHexChat.Repo.insert()

    nick
  end

  # A card in the launcher is the Arcade's address on its game: the patch
  # opens the sheet one message later, after the address is put back.
  defp preview(view, game_id) do
    render_patch(view, "/?arcade=#{game_id}")
    _ = render(view)
    render(view)
  end

  defp arcade_session(view), do: :sys.get_state(view.pid).socket.assigns.arcade_session
  defp open_windows(view), do: :sys.get_state(view.pid).socket.assigns.open_windows

  describe "open_arcade" do
    # The Arcade's folders are a catalogue: opening the Arcade without a game
    # opens them, for anyone, and starts nothing.
    test "without a game opens the Arcade's folder and starts no session", %{conn: conn} do
      nick = "arc#{uid()}"
      register(nick)
      {:ok, view, _} = live(chat_conn(conn, nick, pre_identified: true), "/")

      render_click(view, "open_arcade", %{})

      assert_push_event(view, "window_command", %{action: "open", id: "desktop-launcher-arcade"})
      assert arcade_session(view) == nil
      refute "arcade-games" in open_windows(view)
    end

    test "an unidentified nickname browses the folder without being asked", %{conn: conn} do
      {:ok, view, _} = live(chat_conn(conn, "guest#{uid()}"), "/")

      render_click(view, "open_arcade", %{})

      assert_push_event(view, "window_command", %{action: "open", id: "desktop-launcher-arcade"})
      assert arcade_session(view) == nil
    end

    # Scores are kept against a nickname: picking a game with one not
    # identified is sent to the sign-in window, which comes back to that game.
    test "an unidentified nickname picking a game is asked to sign in, and comes back to it",
         %{conn: conn} do
      {:ok, view, _} = live(chat_conn(conn, "guest#{uid()}"), "/")

      render_click(view, "open_arcade", %{"game-id" => "hacx"})

      assert_patch(view, "/connect?return_to=%2F%3Farcade%3Dhacx&signup=games")
      assert arcade_session(view) == nil
    end

    test "a game opens the window on its sheet and creates a lobby session", %{conn: conn} do
      nick = "arcd#{uid()}"
      registered = register(nick)
      {:ok, view, _} = live(chat_conn(conn, nick, pre_identified: true), "/")

      render_click(view, "open_arcade", %{"game-id" => "doom_shareware"})

      assert %{
               status: "lobby",
               user_id: user_id,
               token: token,
               previewed_game: %{id: "doom_shareware"}
             } = arcade_session(view)

      assert user_id == registered.id
      assert "arcade-games" in open_windows(view)
      assert {:ok, %{status: "lobby", game_id: nil}} = Arcade.get_session(token)
    end
  end

  # The Arcade's folder is called "Arcade" too: the window carries its game,
  # so the two read apart on the taskbar.
  describe "the window's name" do
    test "the title bar and the taskbar button name the game", %{conn: conn} do
      nick = "arct#{uid()}"
      register(nick)
      {:ok, view, _} = live(chat_conn(conn, nick, pre_identified: true), "/")

      render_click(view, "open_arcade", %{"game-id" => "doom_shareware"})
      document = view |> render() |> Floki.parse_document!()
      title = "Arcade — DOOM: Knee-Deep in the Dead"

      assert document |> Floki.find(~s([data-testid="arcade-games-window"])) |> Floki.text() =~
               title

      assert document |> Floki.find(~s([data-window-taskbar="arcade-games"])) |> Floki.text() =~
               title
    end
  end

  # The public game page signs a reader in and lands them here: the address
  # names the game, and the chat opens the arcade on it as the menu would.
  describe "/?arcade=<game>" do
    test "opens the arcade already previewing the named game", %{conn: conn} do
      nick = "arcl#{uid()}"
      register(nick)

      {:ok, view, _} =
        live(chat_conn(conn, nick, pre_identified: true), "/?arcade=doom_shareware")

      # The open is sent to itself after mount; a render processes it.
      _ = render(view)

      assert %{status: "lobby", previewed_game: %{id: "doom_shareware"}} = arcade_session(view)
      assert "arcade-games" in open_windows(view)
    end

    # A reconnect mounts on the address in the bar; were `?arcade=` still
    # there, each one would open a new arcade session.
    test "drops the game from the address once it is open", %{conn: conn} do
      nick = "arcp#{uid()}"
      register(nick)

      {:ok, view, _} =
        live(chat_conn(conn, nick, pre_identified: true), "/?arcade=doom_shareware")

      _ = render(view)

      assert_patch(view, "/c/lobby")
    end

    test "naming no game opens the Arcade's folder", %{conn: conn} do
      nick = "arcn#{uid()}"
      register(nick)

      {:ok, view, _} = live(chat_conn(conn, nick, pre_identified: true), "/?arcade=")
      _ = render(view)

      assert_push_event(view, "window_command", %{action: "open", id: "desktop-launcher-arcade"})
      assert arcade_session(view) == nil
    end

    test "a game the arcade does not have opens nothing", %{conn: conn} do
      nick = "arcx#{uid()}"
      register(nick)

      {:ok, view, _} =
        live(chat_conn(conn, nick, pre_identified: true), "/?arcade=no_such_game")

      _ = render(view)

      assert arcade_session(view) == nil
      refute "arcade-games" in open_windows(view)
    end
  end

  # The Start menu walks the same folders the desktop shows: Games ▸ Arcade ▸
  # a category ▸ its games, each opening the Arcade on its sheet.
  describe "Start menu ▸ Games ▸ Arcade" do
    defp start_menu do
      render_component(&StartMenuApp.start_menu_app/1, screen: :chat, windows: [])
      |> Floki.parse_document!()
    end

    test "is a folder of categories, each listing its games" do
      document = start_menu()

      assert [_] = Floki.find(document, ~s([data-testid="start-menu-folder-arcade"]))

      for group <- GameCatalog.groups(:arcade), game <- group.games do
        assert [row] =
                 Floki.find(
                   document,
                   ~s([data-start-submenu-key="desktop-launcher-arcade-#{group.category}"] [data-testid="start-menu-item-game-#{game.id}"])
                 )

        assert Floki.attribute(row, "href") == ["/?arcade=#{game.id}"]
      end

      assert Floki.find(document, ~s([data-testid="start-menu-item-open_arcade"])) == []
    end
  end

  describe "game selection and teardown" do
    setup %{conn: conn} do
      nick = "arcp#{uid()}"
      register(nick)
      {:ok, view, _} = live(chat_conn(conn, nick, pre_identified: true), "/")
      render_click(view, "open_arcade", %{"game-id" => "doom_shareware"})
      %{view: view, token: arcade_session(view).token}
    end

    test "picking another game shows its sheet in the same session", %{view: view, token: token} do
      preview(view, "freedoom1")

      assert %{
               status: "lobby",
               token: ^token,
               previewed_game: %{
                 id: "freedoom1",
                 about: [_ | _],
                 keys: [_ | _],
                 tips: [_ | _]
               }
             } = arcade_session(view)

      assert {:ok, %{status: "lobby", game_id: nil}} = Arcade.get_session(token)
    end

    test "starting a game other than the one on the sheet does nothing", %{
      view: view,
      token: token
    } do
      render_click(view, "arcade_select_game", %{"game-id" => "freedoom1"})

      assert %{status: "lobby", previewed_game: %{id: "doom_shareware"}} = arcade_session(view)
      assert {:ok, %{status: "lobby", game_id: nil}} = Arcade.get_session(token)
    end

    test "starting the previewed game drives the domain to playing", %{view: view, token: token} do
      preview(view, "doom_shareware")
      render_click(view, "arcade_select_game", %{"game-id" => "doom_shareware"})

      # The domain is authoritative and updated synchronously by select_game;
      # assert the persisted status rather than the async status broadcast.
      assert {:ok, %{status: "playing", game_id: "doom_shareware"}} = Arcade.get_session(token)
    end

    # The game tab is opened by an anchor with `rel="noopener"`, so there is no
    # handle to close it with — which is the price of the tab having its own
    # event loop. Back ends the *session*, and the tab the person opened stays
    # theirs to close.
    test "Back after a game ends the session and returns to the game's category", %{
      view: view,
      token: token
    } do
      render_click(view, "arcade_select_game", %{"game-id" => "doom_shareware"})
      render(view)

      assert %{status: "playing", token: ^token} = arcade_session(view)

      render_click(view, "arcade_back_to_launcher", %{})

      refute_push_event(view, "close_game_window", %{})

      assert_push_event(view, "window_command", %{
        action: "open",
        id: "desktop-launcher-arcade-fps"
      })

      assert arcade_session(view) == nil
      refute "arcade-games" in open_windows(view)
      assert {:ok, %{status: "closed"}} = Arcade.get_session(token)
    end

    test "Back on a sheet ends the session and returns to the game's category", %{
      view: view,
      token: token
    } do
      preview(view, "scummvm_bass")
      render_click(view, "arcade_back", %{})

      assert_push_event(view, "window_command", %{
        action: "open",
        id: "desktop-launcher-arcade-adventure"
      })

      assert arcade_session(view) == nil
      refute "arcade-games" in open_windows(view)
      assert {:ok, session} = Arcade.get_session(token)
      assert session.status in ["closed", "finished"]
    end

    # The category windows stay open beside the Arcade's: a game picked there
    # after the last one finished is that game's sheet, in a fresh session.
    test "a game picked after one finished starts afresh on its sheet", %{
      view: view,
      token: token
    } do
      send(view.pid, %{
        event: "arcade_status_changed",
        payload: %{status: "finished", token: token, duration_seconds: 5}
      })

      assert %{status: "finished"} = arcade_session(view)

      render_click(view, "open_arcade", %{"game-id" => "freedoom1"})

      assert %{status: "lobby", token: new_token, previewed_game: %{id: "freedoom1"}} =
               arcade_session(view)

      refute new_token == token
      assert {:ok, %{status: "closed"}} = Arcade.get_session(token)
    end

    test "a game the arcade does not have opens its folder, not an empty window", %{
      conn: conn
    } do
      nick = "arcu#{uid()}"
      register(nick)
      {:ok, view, _} = live(chat_conn(conn, nick, pre_identified: true), "/")

      render_click(view, "open_arcade", %{"game-id" => "no_such_game"})

      assert_push_event(view, "window_command", %{action: "open", id: "desktop-launcher-arcade"})
      assert arcade_session(view) == nil
    end

    test "leaving closes the session and unmounts the window", %{view: view, token: token} do
      render_click(view, "arcade_leave", %{})

      assert arcade_session(view) == nil
      refute "arcade-games" in open_windows(view)
      assert {:ok, session} = Arcade.get_session(token)
      assert session.status in ["closed", "finished"]
    end
  end
end
