defmodule RetroHexChatWeb.ComposerPlaceholderTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  test "composer placeholder follows the active channel after switch_tab", %{conn: conn} do
    nick = "probe#{uid()}"
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

    view
    |> element(~s([data-testid="chat-input-form"]))
    |> render_submit(%{"input" => "/join #probe1"})

    assert render(view) =~ "Message to #probe1"

    render_click(view, "switch_tab", %{"type" => "channel", "label" => "#lobby"})
    assert render(view) =~ "Message to #lobby"

    render_click(view, "switch_tab", %{"type" => "channel", "label" => "#probe1"})
    assert render(view) =~ "Message to #probe1"
  end
end
