defmodule RetroHexChatWeb.TypingIndicatorTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  defp open_pm_with(view, _nick, other) do
    # Initiate PM via context menu
    render_click(view, "nick_right_click", %{"nick" => other, "x" => 0, "y" => 0})
    render_click(view, "context_query", %{"nick" => other})
    render(view)
  end

  defp switch_to_channel(view, channel) do
    view
    |> element(~s(div[phx-click="switch_channel"][phx-value-channel="#{channel}"]))
    |> render_click()
  end

  defp send_typing(view, nickname) do
    send(view.pid, %{event: "typing", payload: %{nickname: nickname}})
    :timer.sleep(5)
  end

  defp send_stop_typing(view, nickname) do
    send(view.pid, %{event: "stop_typing", payload: %{nickname: nickname}})
    :timer.sleep(5)
  end

  # ── Typing indicator display ─────────────────────────────

  describe "typing indicator display" do
    test "shows typing indicator when PM partner types", %{conn: conn} do
      nick = "TInd#{uid()}"
      other = "Alice"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      open_pm_with(view, nick, other)

      send_typing(view, other)

      html = render(view)
      assert html =~ "typing-indicator"
      assert html =~ "#{other} is typing..."
    end

    test "hides typing indicator on stop_typing", %{conn: conn} do
      nick = "TStop#{uid()}"
      other = "Bob"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      open_pm_with(view, nick, other)

      send_typing(view, other)
      html = render(view)
      assert html =~ "typing-indicator"

      send_stop_typing(view, other)
      html = render(view)
      refute html =~ "typing-indicator"
    end

    test "clears typing indicator after timeout", %{conn: conn} do
      nick = "TClr#{uid()}"
      other = "Carol"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      open_pm_with(view, nick, other)

      send_typing(view, other)
      html = render(view)
      assert html =~ "typing-indicator"

      # Simulate the timer firing
      send(view.pid, :clear_typing_indicator)
      :timer.sleep(5)

      html = render(view)
      refute html =~ "typing-indicator"
    end

    test "does not show typing for non-active PM", %{conn: conn} do
      nick = "TNon#{uid()}"
      other = "Dave"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Don't open PM with Dave — stay on channel
      send_typing(view, other)

      html = render(view)
      refute html =~ "typing-indicator"
    end

    test "clears typing indicator on channel switch", %{conn: conn} do
      nick = "TSwC#{uid()}"
      other = "Eve"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      open_pm_with(view, nick, other)

      send_typing(view, other)
      html = render(view)
      assert html =~ "typing-indicator"

      # Switch back to channel
      switch_to_channel(view, "#lobby")

      html = render(view)
      refute html =~ "typing-indicator"
    end

    test "does not show own typing", %{conn: conn} do
      nick = "TOwn#{uid()}"
      other = "Frank"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      open_pm_with(view, nick, other)

      # Send typing event with own nickname
      send_typing(view, nick)

      html = render(view)
      refute html =~ "typing-indicator"
    end
  end

  # ── Typing event broadcasting ────────────────────────────

  describe "typing event broadcasting" do
    test "pm_typing broadcasts to PM topic", %{conn: conn} do
      nick = "TBc#{uid()}"
      other = "Grace"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      open_pm_with(view, nick, other)

      # Subscribe to the PM topic
      topic = "pm:#{Enum.sort([nick, other]) |> Enum.join(":")}"
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, topic)

      render_hook(view, "pm_typing", %{})

      assert_receive %{event: "typing", payload: %{nickname: ^nick}}, 1000
    end

    test "pm_stop_typing broadcasts to PM topic", %{conn: conn} do
      nick = "TSBc#{uid()}"
      other = "Heidi"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      open_pm_with(view, nick, other)

      topic = "pm:#{Enum.sort([nick, other]) |> Enum.join(":")}"
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, topic)

      render_hook(view, "pm_stop_typing", %{})

      assert_receive %{event: "stop_typing", payload: %{nickname: ^nick}}, 1000
    end

    test "pm_typing does nothing without active_pm", %{conn: conn} do
      nick = "TNoPm#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # No PM open — should not crash
      render_hook(view, "pm_typing", %{})
      render_hook(view, "pm_stop_typing", %{})

      # Just verify it didn't crash
      html = render(view)
      assert html =~ nick
    end
  end
end
