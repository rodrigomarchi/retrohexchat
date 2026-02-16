defmodule RetroHexChatWeb.ChannelListLiveTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor

  setup do
    # Ensure a channel exists for listing
    {:ok, _pid} = ChannelSupervisor.start_child("#list_test")
    on_exit(fn -> cleanup_channel("#list_test") end)
    :ok
  end

  describe "mount" do
    test "renders channel list after loading", %{conn: conn} do
      {:ok, view, html} = live(conn, "/channels")
      assert html =~ "Channel List"
      # After async load completes, the channel should appear
      html = render(view)
      assert html =~ "#list_test"
    end

    test "shows loading state initially", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/channels")
      assert html =~ "Fetching channels"
    end
  end

  describe "filter" do
    test "filters channels by text", %{conn: conn} do
      {:ok, _pid} = ChannelSupervisor.start_child("#filter_match")
      on_exit(fn -> cleanup_channel("#filter_match") end)

      {:ok, view, _html} = live(conn, "/channels")
      html = view |> element("input[name=search]") |> render_keyup(%{"search" => "filter"})
      assert html =~ "#filter_match"
      refute html =~ "#list_test"
    end

    test "shows all channels when search is empty", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/channels")
      html = view |> element("input[name=search]") |> render_keyup(%{"search" => ""})
      assert html =~ "#list_test"
    end
  end

  describe "empty channel list" do
    test "shows no channels when none match filter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/channels")

      html =
        view
        |> element("input[name=search]")
        |> render_keyup(%{"search" => "zzz_nonexistent_channel"})

      assert html =~ "No channels found"
    end
  end

  describe "filter with special characters" do
    test "filter with regex metacharacters does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/channels")
      html = view |> element("input[name=search]") |> render_keyup(%{"search" => "[test(.*"})
      # Should not crash — either shows filtered results or "No channels found"
      assert html =~ "Channel List"
    end
  end

  describe "join" do
    test "renders hidden form with join_channel", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/channels")

      html =
        view
        |> element(~s(button[phx-click="join"][phx-value-channel="#list_test"]))
        |> render_click()

      assert html =~ ~s(id="channel-join-form")
      assert html =~ ~s(name="join_channel")
      assert html =~ ~s(value="#list_test")
    end
  end

  describe "close" do
    test "renders hidden form without join_channel", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/channels")
      html = view |> element(~s(button[type="button"][phx-click="close"])) |> render_click()
      assert html =~ ~s(id="channel-join-form")
      refute html =~ ~s(name="join_channel")
    end
  end

  defp cleanup_channel(name) do
    case RetroHexChat.Channels.Registry.lookup(name) do
      {:ok, pid} -> GenServer.stop(pid)
      _ -> :ok
    end
  end
end
