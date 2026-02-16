defmodule RetroHexChatWeb.ChatLiveNickColumnTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias RetroHexChat.Channels.{Registry, Supervisor}

  @moduletag :liveview

  setup %{conn: conn} do
    channel = "#ncol-#{System.unique_integer([:positive])}"
    ensure_channel(channel)
    {:ok, conn: conn, channel: channel}
  end

  describe "US1: Nick Column Alignment" do
    test "regular messages render with chat-msg-grid class", %{conn: conn, channel: channel} do
      nick = "NCol#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      view |> render_submit("send_input", %{"input" => "Hello world"})
      html = render(view)

      assert html =~ "chat-msg-grid"
    end

    test "action messages use full-width layout without grid", %{conn: conn, channel: channel} do
      nick = "NCol#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      view |> render_submit("send_input", %{"input" => "/me waves"})
      html = render(view)

      # Action messages should be present
      assert html =~ "chat-message--action"
      # Action span should NOT be wrapped in chat-msg-grid
      refute Regex.match?(~r/chat-msg-grid[^<]*chat-action/, html)
    end

    test "system messages use full-width layout without grid", %{conn: conn, channel: channel} do
      nick1 = "NC1#{uid()}"
      nick2 = "NC2#{uid()}"

      {:ok, view1, _} = live(chat_conn(conn, nick1), "/chat")
      join_channel(view1, channel)

      # Second user joins — view1 sees a system message via PubSub
      {:ok, view2, _} = live(chat_conn(conn, nick2), "/chat")
      join_channel(view2, channel)

      # Flush PubSub messages
      :timer.sleep(50)
      _ = render(view1)
      html = render(view1)

      # System message about nick2 joining should exist and NOT be in grid
      assert html =~ "chat-system"
      refute Regex.match?(~r/chat-msg-grid[^>]*>.*chat-system/s, html)
    end

    test "multiple nicks all produce grid layout", %{conn: conn, channel: channel} do
      nick1 = "A#{uid()}"
      nick2 = "Med#{uid()}"

      {:ok, view1, _} = live(chat_conn(conn, nick1), "/chat")
      join_channel(view1, channel)

      {:ok, view2, _} = live(chat_conn(conn, nick2), "/chat")
      join_channel(view2, channel)

      view1 |> render_submit("send_input", %{"input" => "short nick msg"})
      view2 |> render_submit("send_input", %{"input" => "medium nick msg"})

      # Flush PubSub messages
      _ = render(view1)
      html = render(view1)

      assert html =~ "chat-msg-grid"
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

  defp uid, do: System.unique_integer([:positive])
end
