defmodule RetroHexChatWeb.Components.StatusBarTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.StatusBar

  @default_assigns %{
    nickname: "alice",
    channel: "#general",
    user_count: 15,
    tab_type: :channel,
    connection_state: :connected,
    lag_ms: nil,
    lag_status: :normal,
    muted: false
  }

  defp render_status_bar(overrides \\ %{}) do
    assigns = Map.merge(@default_assigns, overrides)
    render_component(&StatusBar.status_bar/1, Map.to_list(assigns))
  end

  describe "status_bar/1 left section" do
    test "displays nickname, channel name, and user count" do
      html = render_status_bar()
      assert html =~ ~s(data-testid="status-nick")
      assert html =~ "alice"
      assert html =~ ~s(data-testid="status-channel")
      assert html =~ "#general"
      assert html =~ ~s(data-testid="status-users")
      assert html =~ "(15)"
    end

    test "displays 'No channel' when channel is nil" do
      html = render_status_bar(%{channel: nil})
      assert html =~ "No channel"
    end

    test "displays user count of zero" do
      html = render_status_bar(%{user_count: 0})
      assert html =~ "(0)"
    end
  end

  describe "status_bar/1 PM tab" do
    test "hides user count for PM tab" do
      html = render_status_bar(%{tab_type: :pm, channel: "DoeJoe"})
      refute html =~ ~s(data-testid="status-users")
    end

    test "displays PM nickname in channel field" do
      html = render_status_bar(%{tab_type: :pm, channel: "DoeJoe"})
      assert html =~ ~s(data-testid="status-channel")
      assert html =~ "DoeJoe"
    end

    test "channel tab shows user count" do
      html = render_status_bar(%{tab_type: :channel, channel: "#general", user_count: 5})
      assert html =~ ~s(data-testid="status-users")
      assert html =~ "(5)"
    end
  end

  describe "status_bar/1 connection state" do
    test "shows connected state" do
      html = render_status_bar(%{connection_state: :connected})
      assert html =~ "● On"
      assert html =~ "status-bar-connection--connected"
    end

    test "shows connecting state" do
      html = render_status_bar(%{connection_state: :connecting})
      assert html =~ "◌ ..."
      assert html =~ "status-bar-connection--connecting"
    end

    test "shows disconnected state" do
      html = render_status_bar(%{connection_state: :disconnected})
      assert html =~ "● Off"
      assert html =~ "status-bar-connection--disconnected"
    end

    test "shows reconnecting state" do
      html = render_status_bar(%{connection_state: :reconnecting})
      assert html =~ "↻ ..."
      assert html =~ "status-bar-connection--reconnecting"
    end
  end

  describe "status_bar/1 lag display" do
    test "shows dash when lag is nil and status is normal" do
      html = render_status_bar(%{lag_ms: nil, lag_status: :normal})
      assert html =~ "Lag:"
      assert html =~ "—"
    end

    test "shows question mark when lag is nil and status is timeout" do
      html = render_status_bar(%{lag_ms: nil, lag_status: :timeout})
      assert html =~ "Lag:"
      assert html =~ "?"
    end

    test "shows lag value in ms" do
      html = render_status_bar(%{lag_ms: 45, lag_status: :normal})
      assert html =~ "45ms"
    end

    test "applies normal lag color class" do
      html = render_status_bar(%{lag_ms: 100, lag_status: :normal})
      assert html =~ "status-bar-lag--normal"
    end

    test "applies warning lag color class" do
      html = render_status_bar(%{lag_ms: 300, lag_status: :warning})
      assert html =~ "status-bar-lag--warning"
    end

    test "applies critical lag color class" do
      html = render_status_bar(%{lag_ms: 600, lag_status: :critical})
      assert html =~ "status-bar-lag--critical"
    end

    test "applies timeout lag color class" do
      html = render_status_bar(%{lag_ms: nil, lag_status: :timeout})
      assert html =~ "status-bar-lag--timeout"
    end
  end

  describe "status_bar/1 clock" do
    test "renders clock placeholder" do
      html = render_status_bar()
      assert html =~ "--:--"
    end

    test "clock element has ClockHook" do
      html = render_status_bar()
      assert html =~ "phx-hook=\"ClockHook\""
    end

    test "clock element has unique id" do
      html = render_status_bar()
      assert html =~ "id=\"clock-display\""
    end
  end

  describe "status_bar/1 mute toggle" do
    test "shows speaker icon when not muted" do
      html = render_status_bar(%{muted: false})
      assert html =~ "mute-toggle"
      assert html =~ "<svg"
    end

    test "shows mute icon when muted" do
      html = render_status_bar(%{muted: true})
      assert html =~ "mute-toggle"
      assert html =~ "<svg"
    end
  end

  describe "status_bar/1 layout" do
    test "renders single left section with all items" do
      html = render_status_bar()
      assert html =~ "status-bar-section--left"
    end

    test "lag display has LagHook" do
      html = render_status_bar()
      assert html =~ "phx-hook=\"LagHook\""
    end

    test "lag display has unique id" do
      html = render_status_bar()
      assert html =~ "id=\"lag-display\""
    end

    test "renders separators between right section items" do
      html = render_status_bar()
      assert html =~ "status-bar-separator"
    end
  end
end
