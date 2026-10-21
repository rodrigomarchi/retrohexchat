defmodule RetroHexChatWeb.ChannelListDialogTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Services.Queries, as: ServiceQueries

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

  describe "category" do
    # Registered rooms nobody is holding open: the catalogue lists them with the
    # subject their founder gave them.
    defp register(name, category) do
      {:ok, _} = ServiceQueries.insert_registered_channel(name, "Founder")
      ServiceQueries.update_registered_channel_settings(name, category: category)
      name
    end

    defp panel(view), do: view |> element(~s([data-testid="channel-list-panel"])) |> render()

    test "see more opens on one subject, the filter changes it, and clearing it shows them all",
         %{conn: conn} do
      news = register("#cld_news_#{uid()}", "news")
      games = register("#cld_games_#{uid()}", "games")

      {:ok, view, _html} = live(chat_conn(conn, "CldCat#{uid()}"), "/")

      render_click(view, "conversations_browse_category", %{"category" => "news"})
      assert_push_event(view, "window_command", %{action: "open", id: "channel-list"})

      html = panel(view)
      assert html =~ news
      refute html =~ games
      assert html =~ ~s(data-testid="channel-list-category-strip")

      render_click(view, "channel_list_filter", %{"search" => "", "category" => "games"})
      html = panel(view)
      assert html =~ games
      refute html =~ news

      render_click(view, "channel_list_filter", %{"search" => "", "category" => ""})
      html = panel(view)
      assert html =~ games
      assert html =~ news
      refute html =~ ~s(data-testid="channel-list-category-strip")
    end

    test "reopening the window lists what the filter it still shows says", %{conn: conn} do
      news = register("#cld_keep_news_#{uid()}", "news")
      games = register("#cld_keep_games_#{uid()}", "games")

      {:ok, view, _html} = live(chat_conn(conn, "CldKeep#{uid()}"), "/")

      render_click(view, "conversations_browse_category", %{"category" => "games"})
      render_click(view, "channel_list")

      html = panel(view)
      assert html =~ games
      refute html =~ news
    end

    test "a subject that is not one shows every room", %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(chat_conn(conn, "CldBogus#{uid()}"), "/")

      render_click(view, "channel_list_filter", %{"search" => "", "category" => "bogus"})

      html = panel(view)
      assert html =~ channel
      refute html =~ ~s(data-testid="channel-list-category-strip")
    end
  end

  defp cleanup_channel(name) do
    case RetroHexChat.Channels.Registry.lookup(name) do
      {:ok, pid} -> GenServer.stop(pid)
      _ -> :ok
    end
  end
end
