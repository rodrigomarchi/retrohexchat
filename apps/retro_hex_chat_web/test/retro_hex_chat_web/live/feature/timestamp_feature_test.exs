defmodule RetroHexChatWeb.TimestampFeatureTest do
  @moduledoc """
  E2E tests for timestamp format (hardcoded to DD/MM HH:MM).
  Run with: mix test --only liveview_feature
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  describe "Timestamp Format E2E" do
    test "messages always render with DD/MM HH:MM format", %{conn: conn} do
      nick = "TSE1#{uid()}"
      channel = "#tse-#{uid()}"

      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")

      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/join #{channel}"})

      :timer.sleep(50)

      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "timestamp test"})

      :timer.sleep(100)
      _ = render(view)
      html = render(view)

      assert html =~ ~r/\[\d{2}\/\d{2} \d{2}:\d{2}\]/
      assert html =~ "timestamp test"
    end
  end
end
