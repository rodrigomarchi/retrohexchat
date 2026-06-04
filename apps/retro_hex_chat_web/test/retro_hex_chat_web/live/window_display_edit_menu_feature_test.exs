defmodule RetroHexChatWeb.WindowDisplayEditMenuFeatureTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.{Registry, Supervisor}
  alias RetroHexChatWeb.Components.UI.MenuBarApp

  setup do
    channel = "#edit-#{uid()}"
    ensure_channel(channel)
    {:ok, channel: channel}
  end

  describe "Edit menu entry points" do
    test "Edit menu sits between File and View with Clear, Copy, and Find" do
      document =
        render_component(&MenuBarApp.menu_bar_app/1,
          connected: true,
          is_admin: false,
          on_action: "toolbar_action"
        )
        |> Floki.parse_document!()

      assert trigger_labels(document) == ["File", "Edit", "View", "Tools", "Help"]

      sections = Floki.find(document, "nav > div")
      edit_section = Enum.at(sections, 1)
      view_section = Enum.at(sections, 2)

      assert menu_actions(edit_section) == ["clear_window", "copy_selection", "toggle_search"]
      refute "toggle_search" in menu_actions(view_section)

      edit_html = Floki.raw_html(edit_section)
      assert edit_html =~ "Clear Window"
      assert edit_html =~ "Copy"
      assert edit_html =~ "Find"
      assert edit_html =~ "Ctrl+Shift+F"
      assert edit_html =~ ~s(data-menubar-copy-selection)
    end

    test "Edit menu trigger is disabled before connection" do
      document =
        render_component(&MenuBarApp.menu_bar_app/1,
          connected: false,
          on_action: "toolbar_action"
        )
        |> Floki.parse_document!()

      edit_trigger =
        document
        |> Floki.find("[data-menubar-trigger]")
        |> Enum.at(1)

      assert edit_trigger |> Floki.text() |> String.trim() == "Edit"
      assert Floki.attribute(edit_trigger, "data-disabled") == ["true"]
    end
  end

  describe "clear window action" do
    test "toolbar_action clear_window clears the active chat stream", %{
      conn: conn,
      channel: channel
    } do
      view = connect_user(conn, "EditClear#{uid()}")
      join_channel(view, channel)

      message = "clear-window-marker-#{uid()}"
      render_submit(view, "send_input", %{"input" => message})
      assert render(view) =~ message

      render_click(view, "toolbar_action", %{"action" => "clear_window"})

      refute render(view) =~ message
    end

    test "toolbar_action toggle_search still opens Find after relocation", %{conn: conn} do
      view = connect_user(conn, "EditFind#{uid()}")

      html = render_click(view, "toolbar_action", %{"action" => "toggle_search"})

      assert html =~ "search-bar"
    end
  end

  defp trigger_labels(document) do
    document
    |> Floki.find("[data-menubar-trigger]")
    |> Enum.map(fn trigger -> trigger |> Floki.text() |> String.trim() end)
  end

  defp menu_actions(section) do
    section
    |> Floki.find("[data-testid^=\"context-menu-item-\"]")
    |> Enum.map(fn item ->
      item
      |> Floki.attribute("data-testid")
      |> List.first()
      |> String.replace_prefix("context-menu-item-", "")
    end)
  end

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  defp join_channel(view, channel) do
    render_submit(view, "send_input", %{"input" => "/join #{channel}"})
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
