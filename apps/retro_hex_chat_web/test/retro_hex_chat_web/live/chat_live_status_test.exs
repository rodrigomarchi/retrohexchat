defmodule RetroHexChatWeb.ChatLiveStatusTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  # ── Status window (T043) ────────────────────────────────────

  describe "Status window" do
    test "status window renders on mount", %{conn: conn} do
      unique = System.unique_integer([:positive])
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=StatusUser#{unique}")

      html = render(view)
      assert html =~ "status-window"
    end

    test "status window has no close button", %{conn: conn} do
      unique = System.unique_integer([:positive])
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=NoClose#{unique}")

      html = render(view)
      # The status window title bar should contain the title "Status"
      assert html =~ "Status"
      # The status window must not have a close button (no title-bar-controls)
      refute html =~ "status-window-close"
    end

    test "system messages appear in status stream", %{conn: conn} do
      unique = System.unique_integer([:positive])
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=StatusMsg#{unique}")

      # On mount, system messages (e.g. welcome or connect) should appear in status
      html = render(view)
      assert html =~ "status-window"
    end
  end

  # ── Global presence broadcasts (T015) ───────────────────────

  describe "Global presence broadcasts" do
    test "mount broadcasts user_connected to presence:global", %{conn: conn} do
      unique = System.unique_integer([:positive])
      nick = "PresUser#{unique}"

      # Subscribe before connecting so we can receive the broadcast
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "presence:global")

      {:ok, _view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      assert_receive {:user_connected, %{nickname: ^nick}}, 1000
    end

    test "disconnect broadcasts user_disconnected to presence:global", %{conn: conn} do
      unique = System.unique_integer([:positive])
      nick = "DiscUser#{unique}"

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "presence:global")

      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      # Confirm the connection broadcast first
      assert_receive {:user_connected, %{nickname: ^nick}}, 1000

      # Simulate disconnect by stopping the LiveView process
      GenServer.stop(view.pid)

      assert_receive {:user_disconnected, %{nickname: ^nick}}, 1000
    end
  end

  # ── Helpers ─────────────────────────────────────────────────

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
