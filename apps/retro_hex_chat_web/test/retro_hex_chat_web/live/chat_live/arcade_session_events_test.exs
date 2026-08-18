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
  alias RetroHexChatWeb.Components.UI.MenuBarApp

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

  describe "Games menu" do
    test "shows Arcade as a single launcher entry when available" do
      document =
        render_component(&MenuBarApp.menu_bar_app/1,
          connected: true,
          arcade_available: true,
          on_action: "toolbar_action"
        )
        |> Floki.parse_document!()

      assert [_ | _] = Floki.find(document, ~s([data-testid="context-menu-item-open_arcade"]))
      assert Floki.find(document, ~s([data-testid^="menu-game-"])) == []
    end

    test "hides the per-game entries when the arcade is unavailable" do
      document =
        render_component(&MenuBarApp.menu_bar_app/1,
          connected: true,
          arcade_available: false,
          on_action: "toolbar_action"
        )
        |> Floki.parse_document!()

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

    test "returning to the launcher closes the current popup and starts a fresh lobby", %{
      view: view,
      token: token
    } do
      render_click(view, "arcade_preview", %{"game-id" => "doom_shareware"})
      render_click(view, "arcade_select_game", %{"game-id" => "doom_shareware"})
      render(view)

      assert %{status: "playing", token: ^token} = arcade_session(view)

      render_click(view, "arcade_back_to_launcher", %{})

      assert_push_event(view, "close_game_window", %{})
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
