defmodule RetroHexChatWeb.Site.WindowBodyTest do
  @moduledoc """
  A page's windows share the desktop with the chat, which re-renders on every
  move the reader makes in it. Each window's body is an island fed by values
  that change only with the page, so the chat moving never reaches one — and a
  page arriving does.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChatWeb.Site.WindowBody

  setup do
    test_pid = self()
    handler = "window-body-updates-#{inspect(test_pid)}"

    :telemetry.attach(
      handler,
      [:phoenix, :live_component, :update, :start],
      fn _event, _measurements, %{component: component, assigns_sockets: sockets}, pid ->
        if component == WindowBody, do: send(pid, {:window_body_updated, length(sockets)})
      end,
      test_pid
    )

    on_exit(fn -> :telemetry.detach(handler) end)
  end

  defp flush_updates do
    receive do
      {:window_body_updated, _count} -> flush_updates()
    after
      0 -> :ok
    end
  end

  test "the chat re-rendering leaves every window of the page alone", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/features")
    flush_updates()

    render_click(view, "toggle_mute", %{})
    render_click(view, "toggle_mute", %{})

    refute_received {:window_body_updated, _count}
  end

  test "a page arriving updates its windows", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/features")
    flush_updates()

    render_patch(view, "/faq")

    assert_received {:window_body_updated, _count}
  end
end
