defmodule RetroHexChatWeb.NotifyListEntryPointsFeatureTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.{Registry, Supervisor}

  alias RetroHexChatWeb.Components.UI.{
    MenuBarApp,
    StatusBarApp,
    ToolbarApp
  }

  setup do
    ensure_channel("#lobby")
    :ok
  end

  describe "notify list entry points" do
    test "View menu and Options dropdown expose the Notify List action" do
      menu_html =
        render_component(&MenuBarApp.menu_bar_app/1,
          connected: true,
          on_action: "toolbar_action"
        )

      toolbar_html =
        render_component(&ToolbarApp.toolbar_app/1,
          connected: true,
          on_action: "toolbar_action"
        )

      assert menu_html =~ ~s(data-testid="context-menu-item-toggle_notify_list")
      assert toolbar_html =~ ~s(data-testid="context-menu-item-toggle_notify_list")
      assert menu_html =~ "Notify List"
      assert toolbar_html =~ "Notify List"
    end

    test "toolbar action opens the Notify List window", %{conn: conn} do
      view = connect_user(conn, "NtfMenu#{uid()}")

      refute has_element?(view, ~s([data-window-id="notify-list"]))

      render_click(view, "toolbar_action", %{"action" => "toggle_notify_list"})

      assert has_element?(view, ~s([data-window-id="notify-list"][data-window-managed="true"]))
      assert_push_event(view, "window_command", %{action: "open", id: "notify-list"})
    end

    test "status bar component hides zero count and shows positive buddy count badge" do
      zero_html =
        render_component(&StatusBarApp.status_bar_app/1,
          online_buddy_count: 0,
          on_notify_toggle: "toggle_notify_list"
        )

      buddy_html =
        render_component(&StatusBarApp.status_bar_app/1,
          online_buddy_count: 2,
          on_notify_toggle: "toggle_notify_list"
        )

      refute zero_html =~ ~s(data-testid="status-bar-notify-badge")
      assert buddy_html =~ ~s(data-testid="status-bar-notify-badge")
      assert buddy_html =~ ~s(title="2 buddies online")
      assert buddy_html =~ ">2<"
    end

    test "online buddies render a clickable tray badge in chat", %{conn: conn} do
      buddy = "Buddy#{uid()}"
      watcher = "Watch#{uid()}"

      {:ok, _buddy_view, _html} = live(chat_conn(conn, buddy), "/chat")
      view = connect_user(conn, watcher)

      refute has_element?(view, ~s([data-testid="tray-notify-badge"]))

      render_click(view, "toggle_notify_list")
      # The Notify List is a stateful island in a managed window; fire its
      # events element-based.
      view
      |> element(~s([data-window-id="notify-list"] [phx-click='notify_add_dialog']))
      |> render_click()

      view
      |> element(~s([data-testid="notify-add-form"]))
      |> render_submit(%{"nickname" => buddy, "note" => ""})

      assert has_element?(view, ~s([data-testid="tray-notify-badge"]))
      assert render(view) =~ ~s(title="1 buddy online")

      # Re-invoking the action focuses the window (never toggle-closes); close it
      # via the client contract instead.
      render_hook(view, "window_closed", %{"id" => "notify-list"})
      refute has_element?(view, ~s([data-window-id="notify-list"]))

      view
      |> element(~s([data-testid="tray-notify-badge"]))
      |> render_click()

      assert has_element?(view, ~s([data-window-id="notify-list"]))
    end
  end

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
