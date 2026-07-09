defmodule RetroHexChatWeb.ChatLive.ArcadeSessionEventsTest do
  @moduledoc """
  In-chat solo arcade flow: the Games → Arcade menu opens a managed window and
  creates a solo session; previewing/selecting a game drives the domain; leaving
  closes it. Asserts on synchronous LiveView state (`:sys.get_state`) and
  persisted domain rows — never on async broadcasts.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Arcade
  alias RetroHexChat.Services.RegisteredNick

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
  end

  describe "game selection and teardown" do
    setup %{conn: conn} do
      nick = "arcp#{uid()}"
      register(nick)
      {:ok, view, _} = live(chat_conn(conn, nick, pre_identified: true), "/chat")
      render_click(view, "toolbar_action", %{"action" => "open_arcade"})
      %{view: view, token: arcade_session(view).token}
    end

    test "previewing a game stores the previewed game", %{view: view} do
      render_click(view, "arcade_preview", %{"game-id" => "doom_shareware"})
      assert %{previewed_game: %{id: "doom_shareware"}} = arcade_session(view)

      render_click(view, "arcade_back", %{})
      assert %{previewed_game: nil} = arcade_session(view)
    end

    test "selecting a game drives the domain to playing", %{view: view, token: token} do
      render_click(view, "arcade_select_game", %{"game-id" => "doom_shareware"})

      # The domain is authoritative and updated synchronously by select_game;
      # assert the persisted status rather than the async status broadcast.
      assert {:ok, %{status: "playing", game_id: "doom_shareware"}} = Arcade.get_session(token)
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
