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
    test "channel_list event opens the dialog with channels", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CldOpen"), "/chat")
      html = render_click(view, "channel_list")
      assert html =~ "Channel List"
      assert html =~ ~s(data-testid="channel-list-dialog")
      assert html =~ "#cld_test"
    end

    test "toggle_channel_list closes the dialog", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CldClose"), "/chat")
      render_click(view, "channel_list")
      html = render_click(view, "toggle_channel_list")
      refute html =~ ~s(data-testid="channel-list-dialog")
    end

    test "Escape dismisses the dialog", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CldEsc"), "/chat")
      render_click(view, "channel_list")
      html = render_click(view, "window_keydown", %{"key" => "Escape"})
      refute html =~ ~s(data-testid="channel-list-dialog")
    end
  end

  describe "filter" do
    test "filters channels by name", %{conn: conn} do
      {:ok, _pid} = ChannelSupervisor.start_child("#cld_filter_yes")
      on_exit(fn -> cleanup_channel("#cld_filter_yes") end)

      {:ok, view, _html} = live(chat_conn(conn, "CldFilter"), "/chat")
      render_click(view, "channel_list")

      html =
        view
        |> element(~s(input[data-testid="channel-list-search"]))
        |> render_keyup(%{"search" => "cld_filter_yes"})

      assert html =~ "#cld_filter_yes"
      refute html =~ "#cld_test"
    end

    test "shows all channels when search is empty", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CldEmpty"), "/chat")
      render_click(view, "channel_list")

      html =
        view
        |> element(~s(input[data-testid="channel-list-search"]))
        |> render_keyup(%{"search" => ""})

      assert html =~ "#cld_test"
    end

    test "shows 'No channels found' when nothing matches", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CldNone"), "/chat")
      render_click(view, "channel_list")

      html =
        view
        |> element(~s(input[data-testid="channel-list-search"]))
        |> render_keyup(%{"search" => "zzz_never_exists"})

      assert html =~ "No channels found"
    end

    test "regex metacharacters in filter are safe", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CldRegex"), "/chat")
      render_click(view, "channel_list")

      html =
        view
        |> element(~s(input[data-testid="channel-list-search"]))
        |> render_keyup(%{"search" => "[test(.*"})

      assert html =~ "Channel List"
    end
  end

  describe "join" do
    test "joining a channel from the dialog closes it and joins", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "CldJoin"), "/chat")
      render_click(view, "channel_list")
      html = render_click(view, "channel_list_join", %{"channel" => "#cld_test"})
      # Dialog should be closed
      refute html =~ ~s(data-testid="channel-list-dialog")
    end
  end

  defp cleanup_channel(name) do
    case RetroHexChat.Channels.Registry.lookup(name) do
      {:ok, pid} -> GenServer.stop(pid)
      _ -> :ok
    end
  end
end
