defmodule RetroHexChatWeb.TimestampE2ETest do
  @moduledoc """
  E2E tests for timestamp format configuration (US8).
  Run with: mix test --only e2e
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :e2e

  describe "Timestamp Format E2E" do
    test "default HH:MM format renders timestamps", %{conn: conn} do
      nick = "TSE1#{uid()}"
      channel = "#tse-#{uid()}"

      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")
      view |> render_submit("send_input", %{"input" => "/join #{channel}"})
      :timer.sleep(50)
      view |> render_submit("send_input", %{"input" => "timestamp test"})
      :timer.sleep(100)
      _ = render(view)
      html = render(view)

      assert html =~ ~r/\[\d{2}:\d{2}\]/
      assert html =~ "timestamp test"
    end

    test "changing format via options updates messages", %{conn: conn} do
      nick = "TSE2#{uid()}"
      channel = "#tse2-#{uid()}"

      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")

      # Change to HH:MM:SS format
      render_click(view, "open_options_dialog", %{})

      render_click(view, "options_change_timestamp_format", %{
        "timestamp_format" => "hh_mm_ss"
      })

      render_click(view, "options_apply", %{})

      # Join and send message
      view |> render_submit("send_input", %{"input" => "/join #{channel}"})
      :timer.sleep(50)
      view |> render_submit("send_input", %{"input" => "seconds test"})
      :timer.sleep(100)
      _ = render(view)
      html = render(view)

      # Should show [HH:MM:SS] format with seconds
      assert html =~ ~r/\[\d{2}:\d{2}:\d{2}\]/
    end
  end

  defp uid, do: System.unique_integer([:positive])
end
