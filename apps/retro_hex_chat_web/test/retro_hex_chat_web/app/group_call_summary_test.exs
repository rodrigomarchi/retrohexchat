defmodule RetroHexChatWeb.App.GroupCallSummaryTest do
  @moduledoc """
  The read-model of a call you are not in.

  A summary reaches the chat from three places — the room server, a PubSub
  broadcast, and a database row when the room server has nothing to say — and
  the tab bar, the sidebar badge and the live card all read the same shape from
  it. What is asserted here is that the shape survives every one of those
  sources, including the one that carries nothing at all.
  """
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChatWeb.App.GroupCallSummary

  describe "normalize/2" do
    test "a channel with no summary still has the shape a reader walks" do
      summary = GroupCallSummary.normalize(nil, "#retro")

      assert summary.room.channel_name == "#retro"
      assert summary.room.id == nil
      assert summary.room.status == "open"
      assert summary.participants == []
      assert summary.pending_participants == []
      assert summary.tracks == []
      assert is_map(summary.server_stats)
      assert summary.participant_quality.by_participant == %{}
    end

    test "reads a broadcast that spells its fields as strings" do
      summary =
        GroupCallSummary.normalize(
          %{
            "room" => %{"id" => 7, "token" => "tok", "status" => "open"},
            "participants" => [%{"id" => 1, "nickname" => "ana"}]
          },
          "#retro"
        )

      assert summary.room.id == 7
      assert summary.room.token == "tok"
      assert [%{id: 1, nickname: "ana"}] = summary.participants
    end

    # A broadcast that lost its room still belongs to the channel it arrived
    # for: the tab bar has nowhere else to learn which channel it is drawing.
    test "borrows the channel name when the payload carries a flat room" do
      summary = GroupCallSummary.normalize(%{"token" => "tok", "status" => "open"}, "#retro")

      assert summary.room.channel_name == "#retro"
      assert summary.room.token == "tok"
    end

    test "keeps the channel name a nested room already carries" do
      summary =
        GroupCallSummary.normalize(%{room: %{channel_name: "#other", token: "tok"}}, "#retro")

      assert summary.room.channel_name == "#other"
    end

    # The reattach path on reconnect feeds an already-normalised summary back
    # in. If a second pass changed the shape, a rejoin would build a different
    # call than the first join did.
    test "normalising twice changes nothing" do
      once = GroupCallSummary.normalize(%{"room" => %{"id" => 7, "token" => "tok"}}, "#retro")

      assert GroupCallSummary.normalize(once, "#retro") == once
    end
  end
end
