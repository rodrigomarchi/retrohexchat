defmodule RetroHexChatWeb.WhowasTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.{Registry, Supervisor}
  alias RetroHexChat.Presence.WhowasCache

  setup do
    ensure_channel("#lobby")
    :ok
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end

  describe "/whowas command" do
    test "shows whowas info for recently disconnected user", %{conn: conn} do
      nick = "Was1#{uid()}"
      target = "Was2#{uid()}"

      # Connect target, then disconnect
      {:ok, target_view, _html} = live(chat_conn(conn, target), "/chat")
      GenServer.stop(target_view.pid)
      Process.sleep(100)

      # Now query whowas
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/whowas #{target}"})

      Process.sleep(50)
      html = render(view)

      assert html =~ "Last Seen: #{target}"
      assert html =~ ~s(data-testid="lookup-result-card")
      assert html =~ "Last seen:"
      assert html =~ "#lobby"
    end

    test "shows not-found message for unknown user", %{conn: conn} do
      nick = "Was3#{uid()}"

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/whowas NeverOnline99999"})

      Process.sleep(50)
      html = render(view)

      assert html =~ "No whowas information available for NeverOnline99999"
    end

    test "whowas shows channels the user was in", %{conn: conn} do
      nick = "Was4#{uid()}"
      target = "Was5#{uid()}"

      # Manually record a whowas entry for precise control
      WhowasCache.record(target, ["#lobby", "#elixir"])

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/whowas #{target}"})

      Process.sleep(50)
      html = render(view)

      assert html =~ "#lobby"
      assert html =~ "#elixir"
    end

    test "whowas shows quit message when available", %{conn: conn} do
      nick = "Was6#{uid()}"
      target = "Was7#{uid()}"

      WhowasCache.record(target, ["#lobby"], "See you tomorrow!")

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/whowas #{target}"})

      Process.sleep(50)
      html = render(view)

      assert html =~ "Quit message"
      assert html =~ "See you tomorrow!"
    end

    test "disconnect records whowas entry automatically", %{conn: conn} do
      _nick = "Was8#{uid()}"
      target = "Was9#{uid()}"

      # Connect and disconnect target
      {:ok, target_view, _html} = live(chat_conn(conn, target), "/chat")
      GenServer.stop(target_view.pid)
      Process.sleep(100)

      # Verify entry was recorded in cache
      assert {:ok, entry} = WhowasCache.lookup(target)
      assert entry.nickname == target
      assert "#lobby" in entry.channels
    end
  end
end
