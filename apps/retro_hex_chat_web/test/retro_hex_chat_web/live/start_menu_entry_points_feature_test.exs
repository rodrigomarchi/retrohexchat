defmodule RetroHexChatWeb.StartMenuEntryPointsFeatureTest do
  @moduledoc """
  The Start menu's rows against a running chat, not against rendered markup.

  `StartMenuSymmetryTest` proves the entries are all there and gray in the right
  places. That is a claim about a component. This is the other half: that a row
  the chat renders live is wired to a handler that exists, so an entry cannot be
  added to the menu and reach nothing.

  It matters most for the rows the menu gained from the menu bar, which had
  never been driven from a taskbar before.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  describe "rows the Start menu took over from the menu bar" do
    test "the window toggles flip the chat's own state", %{conn: conn} do
      view = connect_user(conn, "StartTgl#{uid()}")

      before = state(view)
      click(view, "toggle_nicklist")
      assert state(view).show_nicklist != before.show_nicklist

      before = state(view)
      click(view, "toggle_conversations")
      assert state(view).show_conversations != before.show_conversations
    end

    test "Find opens the chat's search", %{conn: conn} do
      view = connect_user(conn, "StartFind#{uid()}")

      refute state(view).search_visible
      click(view, "toggle_search")
      assert state(view).search_visible
    end

    test "Clear Window and Message of the Day reach the command dispatcher",
         %{conn: conn} do
      view = connect_user(conn, "StartCmd#{uid()}")

      # Both delegate to a `/` command rather than to an assign, so what is
      # asserted is that the row survives the round trip at all — a row wired to
      # a missing handler raises instead.
      click(view, "clear_window")
      click(view, "show_motd")

      assert render(view) =~ "chat-messages"
    end

    test "the account rows the menu gained open their windows", %{conn: conn} do
      view = connect_user(conn, "StartAcct#{uid()}")

      click(view, "open_account_register")
      assert_push_event(view, "window_command", %{action: "open", id: "account"})

      click(view, "account_info")
      assert render(view) =~ "chat-messages"
    end

    # A game's row is the Arcade's address on it, live for every reader of
    # the chat; a nickname not proven is sent to the sign-in window, which
    # comes back to that game.
    test "an Arcade game's row asks an unidentified nick to sign in", %{conn: conn} do
      view = connect_user(conn, "StartArc#{uid()}")

      assert has_element?(
               view,
               ~s|[data-testid="start-menu-item-game-doom_shareware"][href="/?arcade=doom_shareware"][data-phx-link="patch"]|
             )

      render_patch(view, "/?arcade=doom_shareware")
      assert_patch(view, "/connect?return_to=%2F%3Farcade%3Ddoom_shareware&signup=games")
    end
  end

  # Clicks the row itself rather than pushing the event, so the testid, the
  # `phx-click` and the `phx-value-action` are all part of what is proven.
  defp click(view, action) do
    view
    |> element(~s([data-testid="start-menu-item-#{action}"]))
    |> render_click()
  end

  defp state(view), do: :sys.get_state(view.pid).socket.assigns

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/")
    view
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
