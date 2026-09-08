defmodule RetroHexChatWeb.ChatLive.Helpers.PresenceTest do
  @moduledoc """
  What the presence helper says when tracking does not go through.

  Tracking the same person twice from one process is not a failure of presence
  — the room lists them exactly once either way — but it is a second ask that
  something made for nothing, and finding what takes a call site. A sweep of
  the browser suite produced ten of these and the message named no path, so
  none of them could be chased.
  """
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  require Logger

  alias RetroHexChatWeb.ChatLive.Helpers.Presence, as: PresenceHelpers

  defp topic, do: "channel:#presence-test-#{System.unique_integer([:positive])}"

  # The suite runs at level `none`, which would swallow the line these tests
  # exist to read.
  setup do
    previous = Logger.level()
    Logger.configure(level: :warning)
    on_exit(fn -> Logger.configure(level: previous) end)
    :ok
  end

  describe "safe_track_user/3" do
    test "says nothing when the presence is taken" do
      log = capture_log(fn -> assert :ok = PresenceHelpers.safe_track_user(topic(), "First") end)

      refute log =~ "already tracked"
    end

    test "a second track from the same process reports where it came from" do
      shared = topic()
      PresenceHelpers.safe_track_user(shared, "Twice")

      log = capture_log(fn -> PresenceHelpers.safe_track_user(shared, "Twice") end)

      assert log =~ "already tracked by this process"
      # The point of the change: the line names the code that asked.
      assert log =~ "presence_test.exs"
    end
  end
end
