defmodule RetroHexChatWeb.AutojoinFeatureTest do
  @moduledoc """
  Feature tests for the Auto-Join window — the channel list that used to be the
  second tab of the Perform dialog.
  Run with: mix test --only liveview_feature
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.{Registry, Supervisor}
  alias RetroHexChatWeb.Components.UI.{MenuBarApp, StartMenuApp, ToolbarApp}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  describe "entry points" do
    # Each surface has its own opening contract: the menu bar and toolbar emit
    # the `open_autojoin_dialog` action, while the start menu drives the window
    # manager directly through `data-window-open`. Asserting one shape for all
    # three would let a missing entry pass on the odd surface out.
    test "all three navigation surfaces offer the window" do
      for {surface, html, testid} <- surfaces() do
        assert html =~ ~s(data-testid="#{testid}"), "#{surface} should offer the Auto-Join window"
      end
    end

    test "the start menu entry targets the managed window" do
      html = render_component(&StartMenuApp.start_menu_app/1, on_action: "toolbar_action")

      assert html =~ ~s(data-window-open="autojoin")
    end

    test "the window mounts managed and unmounts when closed", %{conn: conn} do
      view = connect_user(conn, "E2EAjW#{uid()}")

      refute has_element?(view, ~s([data-window-id="autojoin"]))

      render_click(view, "toolbar_action", %{"action" => "open_autojoin_dialog"})

      assert has_element?(view, ~s([data-window-id="autojoin"][data-window-managed="true"]))
      assert_push_event(view, "window_command", %{action: "open", id: "autojoin"})

      render_hook(view, "window_closed", %{"id" => "autojoin"})
      refute has_element?(view, ~s([data-window-id="autojoin"]))
    end

    test "/autojoin with no arguments opens the window", %{conn: conn} do
      view = connect_user(conn, "E2EAjC#{uid()}")

      submit_command(view, "/autojoin")

      assert has_element?(view, ~s([data-window-id="autojoin"][data-window-managed="true"]))
      assert_push_event(view, "window_command", %{action: "open", id: "autojoin"})
    end
  end

  describe "channel list" do
    test "empty list shows the placeholder", %{conn: conn} do
      view = connect_user(conn, "E2EAjE#{uid()}")

      html = open_autojoin(view)
      assert html =~ "No auto-join channels"
    end

    test "add channel via dialog", %{conn: conn} do
      view = connect_user(conn, "E2EAjA#{uid()}")

      open_autojoin(view)
      click(view, "autojoin_add")
      submit_form(view, "autojoin-add-dialog", %{"channel" => "#ajtest", "key" => ""})

      html = render(view)
      assert html =~ "#ajtest"
    end

    test "remove channel via dialog", %{conn: conn} do
      view = connect_user(conn, "E2EAjR#{uid()}")

      open_autojoin(view)
      click(view, "autojoin_add")
      submit_form(view, "autojoin-add-dialog", %{"channel" => "#ajrem", "key" => ""})

      select_channel(view, "#ajrem")
      click(view, "autojoin_remove")

      html = render(view)
      refute html =~ "#ajrem"
    end

    test "a channel key is stored but never displayed", %{conn: conn} do
      view = connect_user(conn, "E2EAjK#{uid()}")

      open_autojoin(view)
      click(view, "autojoin_add")
      submit_form(view, "autojoin-add-dialog", %{"channel" => "#ajkey", "key" => "s3cret"})

      html = render(view)
      assert html =~ "#ajkey"
      assert html =~ "***"
      refute html =~ "s3cret"
    end

    test "Remove stays disabled until a channel is selected", %{conn: conn} do
      view = connect_user(conn, "E2EAjS#{uid()}")

      open_autojoin(view)
      click(view, "autojoin_add")
      submit_form(view, "autojoin-add-dialog", %{"channel" => "#ajsel", "key" => ""})

      assert has_element?(view, ~s([phx-click="autojoin_remove"][disabled]))

      select_channel(view, "#ajsel")
      refute has_element?(view, ~s([phx-click="autojoin_remove"][disabled]))
    end
  end

  # ── Helpers ────────────────────────────────────────────────────

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  defp open_autojoin(view) do
    render_click(view, "open_autojoin_dialog")
    render(view)
  end

  defp click(view, event) do
    view |> element("[phx-click='#{event}']") |> render_click()
  end

  defp select_channel(view, channel) do
    view
    |> element("[phx-click='autojoin_select'][phx-value-channel='#{channel}']")
    |> render_click()
  end

  defp submit_form(view, testid, params) do
    view |> element(~s([data-testid="#{testid}"])) |> render_submit(params)
  end

  defp submit_command(view, command) do
    view |> element(~s([data-testid="chat-input-form"])) |> render_submit(%{"input" => command})
  end

  defp surfaces do
    [
      {"menu bar",
       render_component(&MenuBarApp.menu_bar_app/1,
         connected: true,
         on_action: "toolbar_action"
       ), "context-menu-item-open_autojoin_dialog"},
      {"start menu",
       render_component(&StartMenuApp.start_menu_app/1, on_action: "toolbar_action"),
       "start-menu-item-autojoin"},
      {"toolbar",
       render_component(&ToolbarApp.toolbar_app/1,
         connected: true,
         on_action: "toolbar_action"
       ), "context-menu-item-open_autojoin_dialog"}
    ]
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
