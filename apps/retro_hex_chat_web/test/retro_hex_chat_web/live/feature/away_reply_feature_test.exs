defmodule RetroHexChatWeb.AwayReplyFeatureTest do
  @moduledoc """
  E2E tests for away auto-reply (US7).
  Run with: mix test --only liveview_feature
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Chat.Queries

  describe "Away Auto-Reply E2E" do
    test "PM to away user persists an away auto-reply for the sender", %{conn: conn} do
      nick1 = "ARE1#{uid()}"
      nick2 = "ARE2#{uid()}"

      {:ok, view1, _} = live(chat_conn(conn, nick1), "/chat")
      {:ok, view2, _} = live(chat_conn(conn, nick2), "/chat")

      submit(view1, "/away Gone for lunch")
      flush(view1)

      submit(view2, "/query #{nick1}")
      flush(view2)
      render_click(view2, "switch_pm", %{"nickname" => nick1})

      submit(view2, "Hello?")
      # flush(view2) sends the PM and enqueues it in nick1's mailbox; flush(view1)
      # then processes it and persists the away auto-reply — all deterministic.
      flush(view2)
      flush(view1)

      assert [reply] = away_replies(nick1, nick2)
      assert reply.content =~ "Gone for lunch"
    end

    test "second PM from the same sender does not persist a duplicate auto-reply", %{conn: conn} do
      nick1 = "ARE3#{uid()}"
      nick2 = "ARE4#{uid()}"

      {:ok, view1, _} = live(chat_conn(conn, nick1), "/chat")
      {:ok, view2, _} = live(chat_conn(conn, nick2), "/chat")

      submit(view1, "/away Busy")
      flush(view1)

      submit(view2, "/query #{nick1}")
      flush(view2)
      render_click(view2, "switch_pm", %{"nickname" => nick1})

      submit(view2, "First message")
      flush(view2)
      flush(view1)

      submit(view2, "Second message")
      flush(view2)
      flush(view1)

      # Auto-reply is deduplicated per sender, so exactly one is persisted.
      assert [_only_one] = away_replies(nick1, nick2)
    end
  end

  defp submit(view, input) do
    view |> element(~s([data-testid="chat-input-form"])) |> render_submit(%{"input" => input})
  end

  # A :sys.get_state call is FIFO-ordered behind the composer's async dispatch and
  # any already-enqueued PubSub message, so it drains the LiveView deterministically.
  defp flush(view), do: :sys.get_state(view.pid)

  # Auto-reply PMs sent by the away user (nick1) to the sender (nick2). The sender's
  # own messages share the same PM thread, so we filter to nick1's "is away" lines.
  defp away_replies(away_nick, sender) do
    away_nick
    |> Queries.list_private_messages(sender)
    |> Map.fetch!(:items)
    |> Enum.filter(&(&1.sender_nickname == away_nick and &1.content =~ "is away"))
  end
end
