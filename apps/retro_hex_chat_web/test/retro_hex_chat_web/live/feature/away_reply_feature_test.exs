defmodule RetroHexChatWeb.AwayReplyFeatureTest do
  @moduledoc """
  E2E tests for away auto-reply (US7).
  Run with: mix test --only liveview_feature
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  describe "Away Auto-Reply E2E" do
    test "PM to away user triggers auto-reply for sender", %{conn: conn} do
      nick1 = "ARE1#{uid()}"
      nick2 = "ARE2#{uid()}"

      {:ok, view1, _} = live(chat_conn(conn, nick1), "/chat")
      {:ok, view2, _} = live(chat_conn(conn, nick2), "/chat")

      # Nick1 sets away
      view1 |> render_submit("send_input", %{"input" => "/away Gone for lunch"})

      # Nick2 opens PM to nick1
      view2 |> render_submit("send_input", %{"input" => "/query #{nick1}"})
      render_click(view2, "switch_pm", %{"nickname" => nick1})

      # Nick2 sends a PM
      view2 |> render_submit("send_input", %{"input" => "Hello?"})

      # Force view1 to process {:incoming_pm_notify} and send auto-reply
      _ = render(view1)
      :timer.sleep(50)
      _ = render(view2)
      html = render(view2)

      assert html =~ "is away"
      assert html =~ "Gone for lunch"
    end

    test "second PM from same sender does not duplicate auto-reply", %{conn: conn} do
      nick1 = "ARE3#{uid()}"
      nick2 = "ARE4#{uid()}"

      {:ok, view1, _} = live(chat_conn(conn, nick1), "/chat")
      {:ok, view2, _} = live(chat_conn(conn, nick2), "/chat")

      # Nick1 sets away
      view1 |> render_submit("send_input", %{"input" => "/away Busy"})

      # Nick2 opens PM and sends two messages
      view2 |> render_submit("send_input", %{"input" => "/query #{nick1}"})
      render_click(view2, "switch_pm", %{"nickname" => nick1})

      view2 |> render_submit("send_input", %{"input" => "First message"})
      _ = render(view1)
      :timer.sleep(50)
      _ = render(view2)
      html_after_first = render(view2)
      first_count = count_occurrences(html_after_first, "is away")

      view2 |> render_submit("send_input", %{"input" => "Second message"})
      _ = render(view1)
      :timer.sleep(50)
      _ = render(view2)
      html_after_second = render(view2)
      second_count = count_occurrences(html_after_second, "is away")

      # Auto-reply should appear exactly once
      assert first_count >= 1
      assert second_count == first_count
    end
  end

  defp count_occurrences(string, pattern) do
    string
    |> String.split(pattern)
    |> length()
    |> Kernel.-(1)
  end
end
