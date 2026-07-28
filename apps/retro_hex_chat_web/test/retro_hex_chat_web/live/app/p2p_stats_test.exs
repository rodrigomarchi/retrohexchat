defmodule RetroHexChatWeb.App.P2PStatsTest do
  use ExUnit.Case, async: true

  alias RetroHexChatWeb.App.P2PStats

  describe "normalize/1" do
    test "keeps the video source for camera vs screen share stats" do
      assert P2PStats.normalize(%{"video" => %{"source" => "screen"}}).video.source == "screen"
      assert P2PStats.normalize(%{"video" => %{"source" => "camera"}}).video.source == "camera"
      assert P2PStats.normalize(%{"video" => %{"source" => "unknown"}}).video.source == "camera"
    end

    test "keeps handshake summary fields from string or atom payloads" do
      assert P2PStats.normalize(%{
               "summary" => %{
                 "connection_state" => "connected",
                 "ice_connection_state" => "completed",
                 "signaling_epoch" => 4,
                 "offer_id" => "p2p-4-2"
               }
             }).summary == %{
               connection_state: "connected",
               ice_connection_state: "completed",
               signaling_epoch: 4,
               offer_id: "p2p-4-2"
             }

      assert P2PStats.normalize(%{
               summary: %{
                 connection_state: "disconnected",
                 ice_connection_state: "disconnected",
                 signaling_epoch: 5,
                 offer_id: "p2p-5-1"
               }
             }).summary == %{
               connection_state: "disconnected",
               ice_connection_state: "disconnected",
               signaling_epoch: 5,
               offer_id: "p2p-5-1"
             }
    end
  end

  describe "empty/0" do
    test "defaults video source to camera" do
      assert P2PStats.empty().video.source == "camera"
    end

    test "defaults handshake summary to empty values" do
      assert P2PStats.empty().summary == %{
               connection_state: "",
               ice_connection_state: "",
               signaling_epoch: 0,
               offer_id: ""
             }
    end
  end
end
