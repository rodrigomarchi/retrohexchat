defmodule RetroHexChatWeb.ChannelListDialogTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor

  # Each test drives one mounted chat through a sequence of events: a mount is
  # what costs, and every step asserts on its own push or render before the
  # next is sent.
  setup do
    channel = "#cld_test_#{uid()}"
    {:ok, _pid} = ChannelSupervisor.start_child(channel)
    on_exit(fn -> cleanup_channel(channel) end)
    %{channel: channel}
  end

  describe "open/close and join" do
    test "channel_list opens the window with channels, toggle only focuses it, joining closes it",
         %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(chat_conn(conn, "CldOpen#{uid()}"), "/")

      render_click(view, "channel_list")
      html = render(view)
      assert html =~ "Channel List"
      assert_push_event(view, "window_command", %{action: "open", id: "channel-list"})
      assert html =~ channel

      # toggle_channel_list opens/focuses the window (never toggle-closes).
      render_click(view, "toggle_channel_list")
      assert_push_event(view, "window_command", %{action: "open", id: "channel-list"})

      # Joining a channel from the dialog closes it client-side.
      render_click(view, "channel_list_join", %{"channel" => channel})
      assert_push_event(view, "window_command", %{action: "close", id: "channel-list"})
    end
  end

  describe "filter" do
    test "filters by name, shows all when empty, says when nothing matches, survives regex",
         %{conn: conn, channel: channel} do
      wanted = "#cld_filter_yes_#{uid()}"
      {:ok, _pid} = ChannelSupervisor.start_child(wanted)
      on_exit(fn -> cleanup_channel(wanted) end)

      {:ok, view, _html} = live(chat_conn(conn, "CldFilter#{uid()}"), "/")
      render_click(view, "channel_list")

      # Filter lives in the LiveComponent — send_update is async; flush with render.
      render_click(view, "channel_list_filter", %{"search" => String.trim_leading(wanted, "#")})
      html = view |> element(~s([data-testid="channel-list-panel"])) |> render()
      assert html =~ wanted
      refute html =~ channel

      render_click(view, "channel_list_filter", %{"search" => ""})
      assert render(view) =~ channel

      render_click(view, "channel_list_filter", %{"search" => "zzz_never_exists"})
      assert render(view) =~ "No channels found"

      render_click(view, "channel_list_filter", %{"search" => "[test(.*"})
      assert render(view) =~ "Channel List"
    end
  end

  defp cleanup_channel(name) do
    case RetroHexChat.Channels.Registry.lookup(name) do
      {:ok, pid} -> GenServer.stop(pid)
      _ -> :ok
    end
  end
end
