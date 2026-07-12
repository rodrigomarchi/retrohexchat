defmodule RetroHexChatWeb.App.P2PStatsTest do
  use ExUnit.Case, async: true

  alias RetroHexChatWeb.App.P2PStats

  describe "normalize/1" do
    test "keeps the video source for camera vs screen share stats" do
      assert P2PStats.normalize(%{"video" => %{"source" => "screen"}}).video.source == "screen"
      assert P2PStats.normalize(%{"video" => %{"source" => "camera"}}).video.source == "camera"
      assert P2PStats.normalize(%{"video" => %{"source" => "unknown"}}).video.source == "camera"
    end
  end

  describe "empty/0" do
    test "defaults video source to camera" do
      assert P2PStats.empty().video.source == "camera"
    end
  end
end
