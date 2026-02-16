defmodule RetroHexChatWeb.FavoritesTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  describe "treebar context menu" do
    test "channel_right_click event opens context menu", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "FavCtx1"), "/chat")

      html =
        view
        |> element("#treebar")
        |> render_hook("channel_right_click", %{"channel" => "#lobby", "x" => 100, "y" => 200})

      assert html =~ "Add to Favorites"
    end

    test "clicking 'Add to Favorites' opens favorite dialog", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "FavCtx2"), "/chat")

      view
      |> element("#treebar")
      |> render_hook("channel_right_click", %{"channel" => "#lobby", "x" => 100, "y" => 200})

      html = view |> render_click("add_to_favorites", %{"channel" => "#lobby"})

      assert html =~ "Add Favorite"
      assert html =~ "#lobby"
    end
  end

  describe "add favorite dialog" do
    test "saves a favorite with description", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "FavAdd1"), "/chat")

      view
      |> element("#treebar")
      |> render_hook("channel_right_click", %{"channel" => "#lobby", "x" => 100, "y" => 200})

      view |> render_click("add_to_favorites", %{"channel" => "#lobby"})

      html =
        view
        |> render_click("save_favorite", %{
          "channel_name" => "#lobby",
          "description" => "Main chat",
          "password" => "",
          "auto_join" => "false"
        })

      # Dialog should be closed and favorite saved
      refute html =~ "data-testid=\"favorite-dialog\""
    end

    test "closing dialog without saving", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "FavAdd2"), "/chat")

      view
      |> element("#treebar")
      |> render_hook("channel_right_click", %{"channel" => "#lobby", "x" => 100, "y" => 200})

      view |> render_click("add_to_favorites", %{"channel" => "#lobby"})
      html = view |> render_click("close_favorite_dialog", %{})

      refute html =~ "data-testid=\"favorite-dialog\""
    end
  end

  describe "favorites menu" do
    test "shows favorites in menu", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "FavMenu1"), "/chat")

      # Add a favorite
      view
      |> element("#treebar")
      |> render_hook("channel_right_click", %{"channel" => "#lobby", "x" => 100, "y" => 200})

      view |> render_click("add_to_favorites", %{"channel" => "#lobby"})

      view
      |> render_click("save_favorite", %{
        "channel_name" => "#lobby",
        "description" => "Main chat",
        "password" => "",
        "auto_join" => "false"
      })

      html = render(view)
      assert html =~ "Favorites"
      assert html =~ "menu-fav-#lobby"
    end

    test "shows checkmark for joined channel", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "FavMenu2"), "/chat")

      # Add favorite for #lobby (already joined)
      view
      |> element("#treebar")
      |> render_hook("channel_right_click", %{"channel" => "#lobby", "x" => 100, "y" => 200})

      view |> render_click("add_to_favorites", %{"channel" => "#lobby"})

      view
      |> render_click("save_favorite", %{
        "channel_name" => "#lobby",
        "description" => "",
        "password" => "",
        "auto_join" => "false"
      })

      html = render(view)
      assert html =~ "fav-check"
    end

    test "clicking favorite joins channel", %{conn: conn} do
      ensure_channel("#favjoin")
      {:ok, view, _html} = live(chat_conn(conn, "FavMenu3"), "/chat")

      # Add #favjoin as favorite (not joined)
      view
      |> element("#treebar")
      |> render_hook("channel_right_click", %{"channel" => "#lobby", "x" => 100, "y" => 200})

      view |> render_click("add_to_favorites", %{"channel" => "#lobby"})

      view
      |> render_click("save_favorite", %{
        "channel_name" => "#favjoin",
        "description" => "Join test",
        "password" => "",
        "auto_join" => "false"
      })

      html = view |> render_click("join_favorite", %{"channel" => "#favjoin"})
      assert html =~ "#favjoin"
    end

    test "clicking already-joined favorite switches to it", %{conn: conn} do
      ensure_channel("#favsw")
      {:ok, view, _html} = live(chat_conn(conn, "FavMenu4"), "/chat")

      # Join a second channel
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #favsw"})

      # Add #lobby as favorite
      view
      |> element("#treebar")
      |> render_hook("channel_right_click", %{"channel" => "#lobby", "x" => 100, "y" => 200})

      view |> render_click("add_to_favorites", %{"channel" => "#lobby"})

      view
      |> render_click("save_favorite", %{
        "channel_name" => "#lobby",
        "description" => "",
        "password" => "",
        "auto_join" => "false"
      })

      # Switch to #favsw first
      view |> render_click("switch_channel", %{"channel" => "#favsw"})

      # Now click the favorite to switch back to #lobby
      html = view |> render_click("join_favorite", %{"channel" => "#lobby"})

      # Should have switched back to #lobby
      assert html =~ "tree-active"
    end

    test "shows 'No favorites' when empty", %{conn: conn} do
      {:ok, _view, html} = live(chat_conn(conn, "FavEmpty1"), "/chat")
      assert html =~ "No favorites"
    end

    test "shows Organize Favorites menu item", %{conn: conn} do
      {:ok, _view, html} = live(chat_conn(conn, "FavOrg1"), "/chat")
      assert html =~ "Organize Favorites"
    end
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
