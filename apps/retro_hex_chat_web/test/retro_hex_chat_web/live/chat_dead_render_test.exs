defmodule RetroHexChatWeb.ChatDeadRenderTest do
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

  # The disconnected render of /chat is covered edge to edge by a boot overlay
  # and thrown away the moment the socket joins, so every byte of desktop it
  # carried was parsed into a DOM nobody saw and then patched over. It ships the
  # overlay instead, and the desktop arrives with the connected render.

  describe "the disconnected render" do
    setup %{conn: conn} do
      %{html: conn |> chat_conn("Dead#{uid()}") |> get(~p"/chat") |> html_response(200)}
    end

    test "shows the boot overlay", %{html: html} do
      assert html =~ ~s(data-testid="chat-boot-loading")
    end

    test "does not carry the desktop nobody can see", %{html: html} do
      refute html =~ ~s(data-testid="chat-desktop")
      refute html =~ ~s(data-testid="menu-bar")
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
      {:ok, view, _html} = conn |> chat_conn("Live#{uid()}") |> live(~p"/chat")
      html = render(view)

      assert html =~ ~s(data-testid="chat-desktop")
      assert html =~ ~s(data-testid="menu-bar")
      refute html =~ ~s(data-testid="chat-boot-loading")
    end
  end
end
