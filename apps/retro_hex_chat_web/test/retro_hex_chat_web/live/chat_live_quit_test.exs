defmodule RetroHexChatWeb.ChatLiveQuitTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias RetroHexChat.Channels.{Registry, Supervisor}

  @moduletag :liveview

  setup %{conn: conn} do
    channel = "#quit-#{uid()}"
    ensure_channel(channel)
    {:ok, conn: conn, channel: channel}
  end

  describe "US6: Quit message broadcast" do
    test "/quit with message uses that message as part reason", %{
      conn: conn,
      channel: channel
    } do
      nick1 = "QT1#{uid()}"
      nick2 = "QT2#{uid()}"

      {:ok, view1, _} = live(chat_conn(conn, nick1), "/chat")
      join_channel(view1, channel)

      {:ok, view2, _} = live(chat_conn(conn, nick2), "/chat")
      join_channel(view2, channel)

      # Wait for PubSub subscriptions to settle
      :timer.sleep(50)
      _ = render(view2)

      # User1 quits with a message
      view1 |> render_submit("send_input", %{"input" => "/quit Goodbye everyone!"})

      :timer.sleep(50)
      _ = render(view2)
      html = render(view2)

      # User2 should see the quit reason in the leave message
      assert html =~ "Goodbye everyone!"
    end

    test "/quit without message uses default 'Leaving'", %{conn: conn, channel: channel} do
      nick1 = "QT3#{uid()}"
      nick2 = "QT4#{uid()}"

      {:ok, view1, _} = live(chat_conn(conn, nick1), "/chat")
      join_channel(view1, channel)

      {:ok, view2, _} = live(chat_conn(conn, nick2), "/chat")
      join_channel(view2, channel)

      :timer.sleep(50)
      _ = render(view2)

      # User1 quits without a message
      view1 |> render_submit("send_input", %{"input" => "/quit"})

      :timer.sleep(50)
      _ = render(view2)
      html = render(view2)

      assert html =~ "Leaving"
    end

    test "quit message is truncated to 200 characters", %{conn: conn, channel: channel} do
      nick1 = "QT5#{uid()}"
      nick2 = "QT6#{uid()}"

      {:ok, view1, _} = live(chat_conn(conn, nick1), "/chat")
      join_channel(view1, channel)

      {:ok, view2, _} = live(chat_conn(conn, nick2), "/chat")
      join_channel(view2, channel)

      :timer.sleep(50)
      _ = render(view2)

      long_reason = String.duplicate("a", 250)
      view1 |> render_submit("send_input", %{"input" => "/quit #{long_reason}"})

      :timer.sleep(50)
      _ = render(view2)
      html = render(view2)

      # Should contain truncated version (200 chars)
      assert html =~ String.duplicate("a", 200)
      # Should NOT contain full 250 chars
      refute html =~ String.duplicate("a", 250)
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
