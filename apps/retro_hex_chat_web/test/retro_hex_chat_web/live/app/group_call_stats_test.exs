defmodule RetroHexChatWeb.App.GroupCallStatsTest do
  use ExUnit.Case, async: true

  alias RetroHexChatWeb.App.GroupCallStats

  describe "normalize/1" do
    test "keeps browser summary handshake fields" do
      stats =
        GroupCallStats.normalize(%{
          "summary" => %{
            "connection_state" => "connected",
            "participant_count" => 3,
            "remote_stream_count" => 2,
            "track_count" => 5,
            "offer_id" => "gc-9-1",
            "rejoin_epoch" => 2
          }
        })

      assert stats.summary.connection_state == "connected"
      assert stats.summary.offer_id == "gc-9-1"
      assert stats.summary.rejoin_epoch == 2
    end
  end

  describe "empty/0" do
    test "defaults handshake summary fields to empty values" do
      assert GroupCallStats.empty().summary.offer_id == ""
      assert GroupCallStats.empty().summary.rejoin_epoch == 0
    end
  end
end
