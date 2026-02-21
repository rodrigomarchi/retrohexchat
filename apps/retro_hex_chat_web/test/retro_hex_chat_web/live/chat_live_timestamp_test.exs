defmodule RetroHexChatWeb.ChatLiveTimestampTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :liveview

  describe "timestamp format" do
    test "messages render with [DD/MM HH:MM] format", %{conn: conn} do
      nick = "TS1#{uid()}"
      channel = "#tsd-#{uid()}"

      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")
      view |> render_submit("send_input", %{"input" => "/join #{channel}"})
      :timer.sleep(50)
      view |> render_submit("send_input", %{"input" => "hello world"})
      :timer.sleep(100)
      _ = render(view)
      html = render(view)

      assert html =~ ~r/\[\d{2}\/\d{2} \d{2}:\d{2}\]/
    end
  end
end
