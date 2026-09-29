defmodule RetroHexChatWeb.DblclickFeatureTest do
  @moduledoc """
  E2E tests for double-click actions (US2).
  Run with: mix test --only liveview_feature
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    channel = "#dble-#{uid()}"
    ensure_channel(channel)
    {:ok, channel: channel}
  end

  describe "Double-Click Actions E2E" do
    test "nicklist_dblclick opens PM tab", %{conn: conn, channel: channel} do
      nick1 = "DE1#{uid()}"
      nick2 = "DE2#{uid()}"

      {:ok, view1, _} = live(chat_conn(conn, nick1), "/chat")
      join_channel(view1, channel)

      {:ok, _view2, _} = live(chat_conn(conn, nick2), "/chat")
      join_channel(view1, channel)

      # Simulate double-click event (would come from ConversationsHook JS)
      render_click(view1, "nicklist_dblclick", %{"nick" => nick2})
      html = render(view1)

      # PM tab should be visible
      assert html =~ nick2
    end

    # Going to a channel you are not in is joining it, on the one click every
    # row answers. The double click that used to carry this was a second gesture
    # for the same intention, and no finger could perform it.
    test "switch_channel joins a channel you are not in", %{conn: conn, channel: channel} do
      nick = "DEJ#{uid()}"
      target = "#dbjt-#{uid()}"
      ensure_channel(target)

      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      render_click(view, "switch_channel", %{"channel" => target})
      html = render(view)

      assert html =~ target
    end

    test "conversations has ConversationsHook", %{conn: conn, channel: channel} do
      nick = "DEH#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)
      html = render(view)

      assert html =~ "ConversationsHook"
    end
  end

  defp join_channel(view, channel) do
    view
    |> element(~s([data-testid="chat-input-form"]))
    |> render_submit(%{"input" => "/join #{channel}"})
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
