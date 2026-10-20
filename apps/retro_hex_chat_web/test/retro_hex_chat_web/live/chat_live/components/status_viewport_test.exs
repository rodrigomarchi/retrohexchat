defmodule RetroHexChatWeb.ChatLive.Components.StatusViewportTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.StatusViewport

  @moduletag :unit

  @line %{
    id: "status-1",
    content: "Welcome to the server",
    type: :system,
    timestamp: ~U[2024-01-01 12:00:00Z]
  }

  test "an insert action streams a status line keyed by id" do
    html =
      render_component(StatusViewport,
        id: StatusViewport.id(),
        action: {:insert, @line}
      )

    assert html =~ ~s(id="status_messages-status-1")
    assert html =~ "Welcome to the server"
  end

  test "is hidden unless the status tab is active" do
    hidden = render_component(StatusViewport, id: StatusViewport.id(), show_status_tab: false)
    assert hidden =~ "hidden"

    shown = render_component(StatusViewport, id: StatusViewport.id(), show_status_tab: true)
    refute shown =~ "hidden"
  end
end
