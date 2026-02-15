defmodule RetroHexChatWeb.ChatLive.Helpers.ConnectionTest do
  use ExUnit.Case, async: true

  alias RetroHexChatWeb.ChatLive.Helpers.Connection

  describe "lag_status/1" do
    test "returns :timeout for nil" do
      assert Connection.lag_status(nil) == :timeout
    end

    test "returns :normal for 0ms" do
      assert Connection.lag_status(0) == :normal
    end

    test "returns :normal for 199ms" do
      assert Connection.lag_status(199) == :normal
    end

    test "returns :warning for 200ms" do
      assert Connection.lag_status(200) == :warning
    end

    test "returns :warning for 499ms" do
      assert Connection.lag_status(499) == :warning
    end

    test "returns :critical for 500ms" do
      assert Connection.lag_status(500) == :critical
    end

    test "returns :critical for 1000ms" do
      assert Connection.lag_status(1000) == :critical
    end
  end
end
