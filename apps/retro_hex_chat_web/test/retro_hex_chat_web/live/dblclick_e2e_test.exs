defmodule RetroHexChatWeb.DblclickE2ETest do
  @moduledoc """
  E2E tests for double-click actions (US2).
  Run with: mix test --only e2e
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :e2e

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    channel = "#dble-#{uid()}"
    ensure_channel(channel)
    {:ok, channel: channel}
  end

  describe "Double-Click Actions E2E" do
    test "nicklist_dblclick opens PM tab", %{conn: conn, channel: channel} do
      nick1 = "DE1#{uid()}"
      nick2 = "DE2#{uid()}"

      {:ok, view1, _} = live(chat_conn(conn, nick1), "/chat")
      join_channel(view1, channel)

      {:ok, _view2, _} = live(chat_conn(conn, nick2), "/chat")
      join_channel(view1, channel)

      # Simulate double-click event (would come from TreebarHook JS)
      render_click(view1, "nicklist_dblclick", %{"nick" => nick2})
      html = render(view1)

      # PM tab should be visible
      assert html =~ nick2
    end

    test "channel_dblclick joins a new channel", %{conn: conn, channel: channel} do
      nick = "DEJ#{uid()}"
      target = "#dbjt-#{uid()}"
      ensure_channel(target)

      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      render_click(view, "channel_dblclick", %{"channel" => target})
      html = render(view)

      assert html =~ target
    end

    test "channel names in chat are wrapped with chat-channel-link", %{
      conn: conn,
      channel: channel
    } do
      nick = "DEL#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      # Send message containing a channel name
      view |> render_submit("send_input", %{"input" => "Check out #general for info"})
      html = render(view)

      assert html =~ "chat-channel-link"
      assert html =~ ~s(data-channel="#general")
    end

    test "treebar has TreebarHook", %{conn: conn, channel: channel} do
      nick = "DEH#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)
      html = render(view)

      assert html =~ "TreebarHook"
    end
  end

  defp join_channel(view, channel) do
    view |> render_submit("send_input", %{"input" => "/join #{channel}"})
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
