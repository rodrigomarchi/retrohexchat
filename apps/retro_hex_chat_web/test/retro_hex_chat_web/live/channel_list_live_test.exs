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
    test "renders channel list", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/channels")
      assert html =~ "Channel List"
      assert html =~ "#list_test"
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
    test "navigates to /chat with join param", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/channels")

      result =
        view
        |> element(~s(button[phx-click="join"][phx-value-channel="#list_test"]))
        |> render_click()

      assert {:error, {:live_redirect, %{to: "/chat?join=%23list_test"}}} = result
    end
  end

  describe "close" do
    test "navigates to /chat", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/channels")
      result = view |> element(~s(button[type="button"][phx-click="close"])) |> render_click()
      assert {:error, {:live_redirect, %{to: "/chat"}}} = result
    end
  end

  defp cleanup_channel(name) do
    case RetroHexChat.Channels.Registry.lookup(name) do
      {:ok, pid} -> GenServer.stop(pid)
      _ -> :ok
    end
  end
end
