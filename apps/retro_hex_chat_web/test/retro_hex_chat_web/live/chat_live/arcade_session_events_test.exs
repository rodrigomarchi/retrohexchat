defmodule RetroHexChatWeb.ChatLive.ArcadeSessionEventsTest do
  @moduledoc """
  In-chat solo arcade flow: the Games → Arcade menu opens a managed window and
  creates a solo session; choosing a game previews it, starting from the preview
  drives the domain, and leaving closes it. Asserts on synchronous LiveView state
  (`:sys.get_state`) and persisted domain rows — never on async broadcasts.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Arcade
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChatWeb.Components.UI.StartMenuApp

  defp register(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> RetroHexChat.Repo.insert()

    nick
  end

  defp arcade_session(view), do: :sys.get_state(view.pid).socket.assigns.arcade_session
  defp open_windows(view), do: :sys.get_state(view.pid).socket.assigns.open_windows

  describe "open_arcade" do
    test "an identified user opens the arcade window and creates a lobby session", %{conn: conn} do
      nick = "arc#{uid()}"
      registered = register(nick)
      {:ok, view, _} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      render_click(view, "toolbar_action", %{"action" => "open_arcade"})

      assert %{status: "lobby", user_id: user_id, token: token} = arcade_session(view)
      assert user_id == registered.id
      assert "arcade-games" in open_windows(view)
      assert {:ok, %{status: "lobby"}} = Arcade.get_session(token)
    end

    test "a guest (unidentified) user does not start a session", %{conn: conn} do
      nick = "guest#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "toolbar_action", %{"action" => "open_arcade"})

      assert arcade_session(view) == nil
      refute "arcade-games" in open_windows(view)
    end

    test "a game id opens the window already previewing that game", %{conn: conn} do
      nick = "arcd#{uid()}"
      register(nick)
      {:ok, view, _} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      render_click(view, "toolbar_action", %{
        "action" => "open_arcade",
        "game-id" => "doom_shareware"
      })

      assert %{status: "lobby", token: token, previewed_game: %{id: "doom_shareware"}} =
               arcade_session(view)

      assert "arcade-games" in open_windows(view)
      assert {:ok, %{status: "lobby", game_id: nil}} = Arcade.get_session(token)
    end
  end

  # Launching the arcade is the Start menu's job — it opens a program of its
  # own, not something the chat window acts on.
  describe "Start menu ▸ Games" do
    defp start_menu(arcade_available) do
      render_component(&StartMenuApp.start_menu_app/1,
        screen: :chat,
        windows: [],
        arcade_available: arcade_available
      )
      |> Floki.parse_document!()
    end

    test "shows Arcade as a single launcher entry, never one row per game" do
      document = start_menu(true)

      assert [row] = Floki.find(document, ~s([data-testid="start-menu-item-open_arcade"]))
      assert Floki.attribute([row], "disabled") == []
      assert Floki.find(document, ~s([data-testid^="menu-game-"])) == []
    end

    test "grays the entry when the arcade is unavailable, and still lists no games" do
      document = start_menu(false)

      assert [row] = Floki.find(document, ~s([data-testid="start-menu-item-open_arcade"]))
      assert Floki.attribute([row], "disabled") != []
      assert Floki.find(document, ~s([data-testid^="menu-game-"])) == []
    end
  end

  describe "game selection and teardown" do
    setup %{conn: conn} do
      nick = "arcp#{uid()}"
      register(nick)
      {:ok, view, _} = live(chat_conn(conn, nick, pre_identified: true), "/chat")
      render_click(view, "toolbar_action", %{"action" => "open_arcade"})
      %{view: view, token: arcade_session(view).token}
    end

    test "renders the lobby as an icon launcher", %{view: view} do
      html = render(view)

      assert html =~ ~s(data-testid="arcade-library")
      assert html =~ ~s(data-testid="arcade-icon-window")
      assert html =~ ~s(data-testid="arcade-icon-grid")
      assert html =~ ~s(data-testid="arcade-status-bar")
      assert html =~ ~s(data-testid="arcade-game-doom_shareware")
      assert html =~ ~s(phx-click="arcade_preview")
    end

    test "previewing a game stores the selected game details", %{view: view, token: token} do
      render_click(view, "arcade_preview", %{"game-id" => "doom_shareware"})

      assert %{
               status: "lobby",
               token: ^token,
               previewed_game: %{id: "doom_shareware", about: [_ | _], controls: [_ | _]}
             } = arcade_session(view)

      assert {:ok, %{status: "lobby", game_id: nil}} = Arcade.get_session(token)
    end

    test "selecting directly without a preview does not start the game", %{
      view: view,
      token: token
    } do
      render_click(view, "arcade_select_game", %{"game-id" => "doom_shareware"})

      assert %{status: "lobby", previewed_game: nil} = arcade_session(view)
      assert {:ok, %{status: "lobby", game_id: nil}} = Arcade.get_session(token)
    end

    test "starting the previewed game drives the domain to playing", %{view: view, token: token} do
      render_click(view, "arcade_preview", %{"game-id" => "doom_shareware"})
      render_click(view, "arcade_select_game", %{"game-id" => "doom_shareware"})

      # The domain is authoritative and updated synchronously by select_game;
      # assert the persisted status rather than the async status broadcast.
      assert {:ok, %{status: "playing", game_id: "doom_shareware"}} = Arcade.get_session(token)
    end

    # The game tab is opened by an anchor with `rel="noopener"`, so there is no
    # handle to close it with — which is the price of the tab having its own
    # event loop. Returning to the launcher ends the *session*, and the tab the
    # person opened stays theirs to close.
    test "returning to the launcher starts a fresh lobby and touches no window", %{
      view: view,
      token: token
    } do
      render_click(view, "arcade_preview", %{"game-id" => "doom_shareware"})
      render_click(view, "arcade_select_game", %{"game-id" => "doom_shareware"})
      render(view)

      assert %{status: "playing", token: ^token} = arcade_session(view)

      render_click(view, "arcade_back_to_launcher", %{})

      refute_push_event(view, "close_game_window", %{})
      assert %{status: "lobby", token: new_token} = arcade_session(view)
      refute new_token == token
      assert "arcade-games" in open_windows(view)
      assert {:ok, %{status: "closed"}} = Arcade.get_session(token)
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
