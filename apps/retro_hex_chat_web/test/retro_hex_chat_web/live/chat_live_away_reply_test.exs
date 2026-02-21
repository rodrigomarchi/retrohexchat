defmodule RetroHexChatWeb.ChatLiveAwayReplyTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :liveview

  setup %{conn: conn} do
    {:ok, conn: conn}
  end

  describe "US7: Away auto-reply" do
    test "PM while away sends auto-reply to sender", %{conn: conn} do
      nick1 = "AR1#{uid()}"
      nick2 = "AR2#{uid()}"

      {:ok, view1, _} = live(chat_conn(conn, nick1), "/chat")
      {:ok, view2, _} = live(chat_conn(conn, nick2), "/chat")

      # Nick1 sets away
      view1 |> render_submit("send_input", %{"input" => "/away Gone for lunch"})

      # Nick2 opens PM conversation to nick1 (opens the tab, subscribes)
      view2 |> render_submit("send_input", %{"input" => "/query #{nick1}"})
      # Switch to the PM tab
      render_click(view2, "switch_pm", %{"nickname" => nick1})

      # Nick2 sends a PM
      view2 |> render_submit("send_input", %{"input" => "Hello?"})

      # Force view1 to process {:incoming_pm_notify} and send auto-reply
      _ = render(view1)
      :timer.sleep(50)
      _ = render(view2)
      html2 = render(view2)

      # Sender should see auto-reply in PM
      assert html2 =~ "is away" or html2 =~ "Gone for lunch"
    end

    test "second PM from same sender does NOT send another auto-reply", %{conn: conn} do
      nick1 = "AR3#{uid()}"
      nick2 = "AR4#{uid()}"

      {:ok, view1, _} = live(chat_conn(conn, nick1), "/chat")
      {:ok, view2, _} = live(chat_conn(conn, nick2), "/chat")

      # Nick1 sets away
      view1 |> render_submit("send_input", %{"input" => "/away Busy"})

      # Nick2 opens PM tab to nick1
      view2 |> render_submit("send_input", %{"input" => "/query #{nick1}"})
      render_click(view2, "switch_pm", %{"nickname" => nick1})

      # First PM
      view2 |> render_submit("send_input", %{"input" => "First message"})
      _ = render(view1)
      :timer.sleep(50)
      _ = render(view2)
      html_after_first = render(view2)
      first_count = count_occurrences(html_after_first, "is away")

      # Second PM
      view2 |> render_submit("send_input", %{"input" => "Second message"})
      _ = render(view1)
      :timer.sleep(50)
      _ = render(view2)
      html_after_second = render(view2)
      second_count = count_occurrences(html_after_second, "is away")

      # Should not have increased
      assert second_count == first_count
    end

    test "clearing away resets replied_to set", %{conn: conn} do
      nick1 = "AR5#{uid()}"
      nick2 = "AR6#{uid()}"

      {:ok, view1, _} = live(chat_conn(conn, nick1), "/chat")
      {:ok, view2, _} = live(chat_conn(conn, nick2), "/chat")

      # Nick2 opens PM to nick1
      view2 |> render_submit("send_input", %{"input" => "/query #{nick1}"})
      render_click(view2, "switch_pm", %{"nickname" => nick1})

      # Set away, get a PM
      view1 |> render_submit("send_input", %{"input" => "/away BRB"})
      view2 |> render_submit("send_input", %{"input" => "Hello"})
      _ = render(view1)
      :timer.sleep(50)
      _ = render(view2)

      # Clear away
      view1 |> render_submit("send_input", %{"input" => "/away"})

      # Set away again
      view1 |> render_submit("send_input", %{"input" => "/away Back soon"})

      # Same sender sends again — should get new auto-reply
      view2 |> render_submit("send_input", %{"input" => "Hello again"})
      _ = render(view1)
      :timer.sleep(50)
      _ = render(view2)
      html = render(view2)

      assert html =~ "Back soon"
    end
  end

  defp count_occurrences(string, pattern) do
    string
    |> String.split(pattern)
    |> length()
    |> Kernel.-(1)
  end
end
