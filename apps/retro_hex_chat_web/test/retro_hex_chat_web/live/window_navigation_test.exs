defmodule RetroHexChatWeb.Live.WindowNavigationTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :liveview

  defp pm_activity(peer) do
    %{
      event: "new_pm",
      payload: %{
        id: System.unique_integer([:positive]),
        sender: peer,
        recipient: "irrelevant",
        content: "hello",
        type: :message,
        timestamp: DateTime.utc_now(),
        peer: peer,
        direction: :incoming
      }
    }
  end

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns

  describe "window_next/window_prev" do
    test "window navigation includes PM tabs opened by incoming activity", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "WinPm#{uid()}"), "/")

      send(view.pid, pm_activity("ClosedPm"))
      render(view)

      # It lands in the sidebar, not in the bar: the bar only carries the
      # conversation in focus, and this one has not taken the screen yet.
      assert has_element?(view, ~s([data-testid="pm-ClosedPm"]))
      refute has_element?(view, ~s([role="tab"][phx-value-type="pm"][phx-value-label="ClosedPm"]))
      refute assigns(view).session.active_pm == "ClosedPm"

      render_click(view, "window_next")
      assert assigns(view).session.active_pm == "ClosedPm"

      render_click(view, "switch_channel", %{"channel" => "#lobby"})
      assert assigns(view).session.active_channel == "#lobby"

      render_click(view, "window_next")
      assert assigns(view).session.active_pm == "ClosedPm"
    end
  end
end
