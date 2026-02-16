defmodule RetroHexChat.P2P.P2PTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.P2P

  @moduletag :unit

  describe "validate_signal/1" do
    test "accepts valid offer" do
      signal = %{"type" => "offer", "sdp" => "v=0\r\n..."}
      assert {:ok, validated} = P2P.validate_signal(signal)
      assert validated.type == "offer"
      assert validated.sdp == "v=0\r\n..."
    end

    test "accepts valid answer" do
      signal = %{"type" => "answer", "sdp" => "v=0\r\n..."}
      assert {:ok, validated} = P2P.validate_signal(signal)
      assert validated.type == "answer"
    end

    test "accepts valid ice-candidate" do
      candidate = %{"candidate" => "candidate:1 1 udp ...", "sdpMid" => "0"}
      signal = %{"type" => "ice-candidate", "candidate" => candidate}
      assert {:ok, validated} = P2P.validate_signal(signal)
      assert validated.type == "ice-candidate"
      assert validated.candidate == candidate
    end

    test "rejects invalid type" do
      signal = %{"type" => "invalid", "sdp" => "..."}
      assert {:error, :invalid_signal} = P2P.validate_signal(signal)
    end

    test "rejects offer without sdp" do
      signal = %{"type" => "offer"}
      assert {:error, :invalid_signal} = P2P.validate_signal(signal)
    end

    test "rejects answer without sdp" do
      signal = %{"type" => "answer"}
      assert {:error, :invalid_signal} = P2P.validate_signal(signal)
    end

    test "rejects ice-candidate without candidate" do
      signal = %{"type" => "ice-candidate"}
      assert {:error, :invalid_signal} = P2P.validate_signal(signal)
    end

    test "rejects missing type" do
      signal = %{"sdp" => "..."}
      assert {:error, :invalid_signal} = P2P.validate_signal(signal)
    end

    test "rejects empty sdp" do
      signal = %{"type" => "offer", "sdp" => ""}
      assert {:error, :invalid_signal} = P2P.validate_signal(signal)
    end
  end
end
