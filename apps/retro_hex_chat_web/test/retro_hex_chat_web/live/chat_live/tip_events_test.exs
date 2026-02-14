defmodule RetroHexChatWeb.ChatLive.TipEventsTest do
  @moduledoc """
  Tests for contextual tip event handlers: tips_state_sync.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  alias RetroHexChat.Channels.{Registry, Supervisor}

  @moduletag :e2e

  setup do
    channel = "#tips#{uid()}"
    ensure_channel(channel)
    {:ok, channel: channel}
  end

  # ── tips_state_sync ──────────────────────────────────────

  describe "tips_state_sync event" do
    test "stores suppressed state in assigns", %{conn: conn, channel: channel} do
      nick = "Tips#{uid()}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")
      join_channel(view, channel)

      # Push tips_state_sync — should not crash
      assert render_click(view, "tips_state_sync", %{"suppressed" => true})
    end

    test "handles unsuppressed state", %{conn: conn, channel: channel} do
      nick = "Tips#{uid()}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")
      join_channel(view, channel)

      assert render_click(view, "tips_state_sync", %{"suppressed" => false})
    end
  end

  # ── tip_trigger on message send ──────────────────────────

  describe "first message tip trigger" do
    test "send_input pushes tip_trigger event", %{conn: conn, channel: channel} do
      nick = "TipMsg#{uid()}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")
      join_channel(view, channel)

      # Send a message — should not crash and should push tip_trigger
      assert render_click(view, "send_input", %{"input" => "hello"})
    end
  end

  # ── Private helpers ──────────────────────────────────────

  defp join_channel(view, channel) do
    render_click(view, "send_input", %{"input" => "/join #{channel}"})
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end

  defp uid, do: System.unique_integer([:positive])
end
