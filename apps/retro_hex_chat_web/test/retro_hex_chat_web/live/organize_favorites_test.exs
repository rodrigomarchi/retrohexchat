defmodule RetroHexChatWeb.OrganizeFavoritesTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  defp add_favorite(view, channel_name, description \\ "") do
    view
    |> element("#treebar")
    |> render_hook("channel_right_click", %{"channel" => "#lobby", "x" => 0, "y" => 0})

    view |> render_click("add_to_favorites", %{"channel" => "#lobby"})

    view
    |> render_click("save_favorite", %{
      "channel_name" => channel_name,
      "description" => description,
      "password" => "",
      "auto_join" => "false"
    })
  end

  describe "organize favorites dialog" do
    test "opens from menu", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "OrgFav1"), "/chat")

      html = view |> render_click("open_organize_favorites", %{})
      assert html =~ "Organize Favorites"
    end

    test "shows favorites list", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "OrgFav2"), "/chat")

      add_favorite(view, "#alpha", "Alpha channel")
      add_favorite(view, "#beta", "Beta channel")

      html = view |> render_click("open_organize_favorites", %{})
      assert html =~ "#alpha"
      assert html =~ "#beta"
      assert html =~ "Alpha channel"
    end

    test "move up reorders favorites", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "OrgFav3"), "/chat")

      add_favorite(view, "#first")
      add_favorite(view, "#second")

      view |> render_click("open_organize_favorites", %{})
      view |> render_click("favorite_select", %{"channel" => "#second"})

      html = view |> render_click("favorite_move_up", %{})

      # Verify #second is now before #first in the rendered HTML
      second_pos = :binary.match(html, "#second") |> elem(0)
      first_pos = :binary.match(html, "#first") |> elem(0)
      assert second_pos < first_pos
    end

    test "move down reorders favorites", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "OrgFav4"), "/chat")

      add_favorite(view, "#first")
      add_favorite(view, "#second")

      view |> render_click("open_organize_favorites", %{})
      view |> render_click("favorite_select", %{"channel" => "#first"})

      html = view |> render_click("favorite_move_down", %{})

      # Verify #first is now after #second
      second_pos = :binary.match(html, "#second") |> elem(0)
      first_pos = :binary.match(html, "#first") |> elem(0)
      assert first_pos > second_pos
    end

    test "edit opens favorite dialog in edit mode", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "OrgFav5"), "/chat")

      add_favorite(view, "#editable", "Original desc")

      view |> render_click("open_organize_favorites", %{})
      view |> render_click("favorite_select", %{"channel" => "#editable"})

      html = view |> render_click("favorite_edit", %{})
      assert html =~ "Edit Favorite"
      assert html =~ "#editable"
    end

    test "remove deletes favorite", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "OrgFav6"), "/chat")

      add_favorite(view, "#removeme")

      view |> render_click("open_organize_favorites", %{})
      view |> render_click("favorite_select", %{"channel" => "#removeme"})

      html = view |> render_click("favorite_remove", %{})
      refute html =~ "#removeme"
    end

    test "close dialog", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "OrgFav7"), "/chat")

      view |> render_click("open_organize_favorites", %{})

      html = view |> render_click("close_organize_favorites", %{})
      refute html =~ "data-testid=\"organize-favorites-dialog\""
    end

    test "shows Password set indicator", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "OrgFav8"), "/chat")

      # Add favorite with password
      view
      |> element("#treebar")
      |> render_hook("channel_right_click", %{"channel" => "#lobby", "x" => 0, "y" => 0})

      view |> render_click("add_to_favorites", %{"channel" => "#lobby"})

      view
      |> render_click("save_favorite", %{
        "channel_name" => "#secret",
        "description" => "",
        "password" => "mypass",
        "auto_join" => "false"
      })

      html = view |> render_click("open_organize_favorites", %{})
      assert html =~ "Password set"
    end
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
