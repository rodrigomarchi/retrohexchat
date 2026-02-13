defmodule RetroHexChatWeb.ChatLiveTimestampTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :liveview

  setup %{conn: conn} do
    {:ok, conn: conn}
  end

  describe "US8: Timestamp format configuration" do
    test "default format renders [HH:MM]", %{conn: conn} do
      nick = "TS1#{uid()}"
      channel = "#tsd-#{uid()}"

      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")
      view |> render_submit("send_input", %{"input" => "/join #{channel}"})
      :timer.sleep(50)
      # Send a message so it arrives via PubSub
      view |> render_submit("send_input", %{"input" => "hello world"})
      :timer.sleep(100)
      _ = render(view)
      html = render(view)

      assert html =~ ~r/\[\d{2}:\d{2}\]/
    end

    test "options_change_timestamp_format event updates draft", %{conn: conn} do
      nick = "TS2#{uid()}"
      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")

      render_click(view, "open_options_dialog", %{})

      html =
        render_click(view, "options_change_timestamp_format", %{
          "timestamp_format" => "hh_mm_ss"
        })

      assert html =~ "hh_mm_ss"
    end

    test ":none format hides timestamps after apply", %{conn: conn} do
      nick = "TS3#{uid()}"
      channel = "#tsn-#{uid()}"

      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")

      # Change format to none via options
      render_click(view, "open_options_dialog", %{})

      render_click(view, "options_change_timestamp_format", %{
        "timestamp_format" => "none"
      })

      render_click(view, "options_apply", %{})

      # Join and send a message to get a timestamp-formatted entry
      view |> render_submit("send_input", %{"input" => "/join #{channel}"})
      :timer.sleep(50)
      view |> render_submit("send_input", %{"input" => "test message"})
      :timer.sleep(100)
      _ = render(view)
      html = render(view)

      # With :none format, no bracketed timestamps should appear
      refute html =~ ~r/\[\d{2}:\d{2}\]/
      refute html =~ ~r/\[\d{2}:\d{2}:\d{2}\]/
    end

    test "timestamp format dd_mm_hh_mm renders date and time", %{conn: conn} do
      nick = "TS4#{uid()}"
      channel = "#tsd2-#{uid()}"

      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")

      # Change format first
      render_click(view, "open_options_dialog", %{})

      render_click(view, "options_change_timestamp_format", %{
        "timestamp_format" => "dd_mm_hh_mm"
      })

      render_click(view, "options_apply", %{})

      # Join and send to get messages with new format
      view |> render_submit("send_input", %{"input" => "/join #{channel}"})
      :timer.sleep(50)
      view |> render_submit("send_input", %{"input" => "test message"})
      :timer.sleep(100)
      _ = render(view)
      html = render(view)

      assert html =~ ~r/\[\d{2}\/\d{2} \d{2}:\d{2}\]/
    end

    test "stream resets on format change", %{conn: conn} do
      nick = "TS5#{uid()}"
      channel = "#tsr-#{uid()}"

      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")

      # Join and send to produce messages with default format
      view |> render_submit("send_input", %{"input" => "/join #{channel}"})
      :timer.sleep(50)
      view |> render_submit("send_input", %{"input" => "before format change"})
      :timer.sleep(100)
      _ = render(view)
      html_before = render(view)

      assert html_before =~ ~r/\[\d{2}:\d{2}\]/

      # Change format — streams reset, old messages cleared
      render_click(view, "open_options_dialog", %{})

      render_click(view, "options_change_timestamp_format", %{
        "timestamp_format" => "hh_mm_ss"
      })

      render_click(view, "options_apply", %{})
      html_after = render(view)

      # Old messages cleared (stream reset)
      refute html_after =~ "before format change"
    end
  end

  defp uid, do: System.unique_integer([:positive])
end
