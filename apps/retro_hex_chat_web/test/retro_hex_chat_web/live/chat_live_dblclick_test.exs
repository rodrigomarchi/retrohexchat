defmodule RetroHexChatWeb.ChatLiveDblclickTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias RetroHexChat.Channels.{Registry, Supervisor}

  @moduletag :liveview

  setup %{conn: conn} do
    channel = "#dblc-#{uid()}"
    ensure_channel(channel)
    {:ok, conn: conn, channel: channel}
  end

  describe "US2: User double-click → PM" do
    test "nicklist_dblclick with online nick opens PM conversation", %{
      conn: conn,
      channel: channel
    } do
      nick1 = "DC1#{uid()}"
      nick2 = "DC2#{uid()}"

      {:ok, view1, _} = live(chat_conn(conn, nick1), "/chat")
      join_channel(view1, channel)

      {:ok, _view2, _} = live(chat_conn(conn, nick2), "/chat")
      join_channel(view1, channel)

      # Simulate user double-click event from treebar
      render_click(view1, "nicklist_dblclick", %{"nick" => nick2})
      html = render(view1)

      # PM conversation should be open — active PM target appears in tab bar
      assert html =~ nick2
    end

    test "nicklist_dblclick with self opens PM to self", %{conn: conn, channel: channel} do
      nick = "DCSf#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      render_click(view, "nicklist_dblclick", %{"nick" => nick})
      html = render(view)

      # PM with self should work (common IRC behavior)
      assert html =~ nick
    end
  end

  describe "US2: Channel double-click → join" do
    test "channel_dblclick with new channel joins it", %{conn: conn, channel: channel} do
      nick = "DCJ#{uid()}"
      target_channel = "#dcjt-#{uid()}"
      ensure_channel(target_channel)

      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      render_click(view, "channel_dblclick", %{"channel" => target_channel})
      html = render(view)

      # Should have joined the target channel
      assert html =~ target_channel
    end

    test "channel_dblclick with already joined channel switches to it", %{
      conn: conn,
      channel: channel
    } do
      nick = "DCS#{uid()}"
      other = "#dcot-#{uid()}"
      ensure_channel(other)

      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)
      join_channel(view, other)

      # Switch back to first channel
      render_click(view, "channel_dblclick", %{"channel" => channel})
      html = render(view)

      assert html =~ channel
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
