defmodule RetroHexChatWeb.ChannelListDialogTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor

  setup do
    {:ok, _pid} = ChannelSupervisor.start_child("#cld_test")
    on_exit(fn -> cleanup_channel("#cld_test") end)
    :ok
  end

  describe "open/close" do
    test "channel_list event opens the window with channels", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CldOpen"), "/chat")
      render_click(view, "channel_list")
      html = render(view)
      assert html =~ "Channel List"
      assert_push_event(view, "window_command", %{action: "open", id: "channel-list"})
      assert html =~ "#cld_test"
    end

    test "toggle_channel_list opens/focuses the window (never toggle-closes)", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CldClose"), "/chat")
      render_click(view, "channel_list")
      render_click(view, "toggle_channel_list")
      assert_push_event(view, "window_command", %{action: "open", id: "channel-list"})
    end
  end

  describe "filter" do
    test "filters channels by name", %{conn: conn} do
      {:ok, _pid} = ChannelSupervisor.start_child("#cld_filter_yes")
      on_exit(fn -> cleanup_channel("#cld_filter_yes") end)

      {:ok, view, _html} = live(chat_conn(conn, "CldFilter"), "/chat")
      render_click(view, "channel_list")

      # Filter lives in the LiveComponent — send_update is async; flush with render.
      render_click(view, "channel_list_filter", %{"search" => "cld_filter_yes"})
      html = view |> element(~s([data-testid="channel-list-panel"])) |> render()

      assert html =~ "#cld_filter_yes"
      refute html =~ "#cld_test"
    end

    test "shows all channels when search is empty", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CldEmpty"), "/chat")
      render_click(view, "channel_list")

      render_click(view, "channel_list_filter", %{"search" => ""})
      html = render(view)

      assert html =~ "#cld_test"
    end

    test "shows 'No channels found' when nothing matches", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CldNone"), "/chat")
      render_click(view, "channel_list")

      render_click(view, "channel_list_filter", %{"search" => "zzz_never_exists"})
      html = render(view)

      assert html =~ "No channels found"
    end

    test "regex metacharacters in filter are safe", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CldRegex"), "/chat")
      render_click(view, "channel_list")

      render_click(view, "channel_list_filter", %{"search" => "[test(.*"})
      html = render(view)

      assert html =~ "Channel List"
    end
  end

  describe "join" do
    test "joining a channel from the dialog closes it and joins", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CldJoin"), "/chat")
      render_click(view, "channel_list")
      render_click(view, "channel_list_join", %{"channel" => "#cld_test"})
      # Joining closes the window client-side.
      assert_push_event(view, "window_command", %{action: "close", id: "channel-list"})
    end
  end

  defp cleanup_channel(name) do
    case RetroHexChat.Channels.Registry.lookup(name) do
      {:ok, pid} -> GenServer.stop(pid)
      _ -> :ok
    end
  end
end
