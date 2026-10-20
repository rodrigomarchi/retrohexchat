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
    # Going to a channel you are not in is joining it, on the one click every
    # row answers. The double click that used to carry this was a second gesture
    # for the same intention, and no finger could perform it.
    test "switch_channel joins a channel you are not in", %{conn: conn, channel: channel} do
      nick = "DEJ#{uid()}"
      target = "#dbjt-#{uid()}"
      ensure_channel(target)

      {:ok, view, _} = live(chat_conn(conn, nick), "/")
      join_channel(view, channel)

      render_click(view, "switch_channel", %{"channel" => target})
      html = render(view)

      assert html =~ target
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
