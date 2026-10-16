defmodule RetroHexChatWeb.DesktopDeadRenderTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.Registry
  alias RetroHexChat.Channels.Supervisor
  alias RetroHexChatWeb.PerfBudgets

  setup do
    case Registry.lookup("#lobby") do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child("#lobby")
    end

    :ok
  end

  # The disconnected render of the desktop is what a reader sees while the chat
  # starts: the desktop's own chrome, and the chat as a window saying it is
  # opening. The chat's body, its menus, folders and dialogs are thrown away
  # and redrawn the moment the socket joins, so they arrive with the connected
  # render instead of being parsed into a DOM nobody could use.

  describe "the disconnected render" do
    setup %{conn: conn} do
      %{html: conn |> chat_conn("Dead#{uid()}") |> get("/") |> html_response(200)}
    end

    test "shows the chat opening", %{html: html} do
      assert html =~ ~s(data-testid="chat-boot-loading")
    end

    test "does not carry what only works once the chat is live", %{html: html} do
      refute html =~ ~s(data-testid="menu-bar")
      refute html =~ ~s(phx-update="stream")
      refute html =~ ~s(data-window-id="desktop-launcher-)
      refute html =~ ~s(data-testid="kick-dialog")
    end

    test "stays inside its byte budget", %{html: html} do
      assert byte_size(html) <= PerfBudgets.html_bytes(:chat)
    end

    test "stays inside its DOM node budget", %{html: html} do
      assert PerfBudgets.count_elements(html) <= PerfBudgets.dom_nodes(:chat)
    end
  end

  describe "the connected render" do
    test "brings the whole desktop with it", %{conn: conn} do
      {:ok, view, _html} = conn |> chat_conn("Live#{uid()}") |> live("/")
      html = render(view)

      assert html =~ ~s(data-testid="menu-bar")
      assert html =~ ~s(data-window-id="desktop-launcher-)
      refute html =~ ~s(data-testid="chat-boot-loading")
    end
  end
end
