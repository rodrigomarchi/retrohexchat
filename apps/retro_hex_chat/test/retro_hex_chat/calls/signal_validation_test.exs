defmodule RetroHexChat.Calls.SignalValidationTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Calls.SignalValidation

  describe "validate_sdp/1" do
    test "accepts a session description" do
      assert {:ok, "v=0\r\n"} = SignalValidation.validate_sdp("v=0\r\n")
    end

    test "accepts one exactly at the bound and refuses one byte past it" do
      assert {:ok, _sdp} = SignalValidation.validate_sdp(String.duplicate("a", 256_000))

      assert {:error, :invalid_signal} =
               SignalValidation.validate_sdp(String.duplicate("a", 256_001))
    end

    test "refuses an empty or non-binary description" do
      for value <- ["", nil, 42, %{}, ~c"charlist"] do
        assert {:error, :invalid_signal} = SignalValidation.validate_sdp(value)
      end
    end
  end

  describe "validate_candidate/1" do
    test "accepts a candidate carrying a media section" do
      candidate = %{"candidate" => "candidate:1 1 udp ...", "sdpMid" => "0"}

      assert {:ok, ^candidate} = SignalValidation.validate_candidate(candidate)
    end

    test "accepts a candidate carrying only an index, including zero" do
      candidate = %{"candidate" => "candidate:1 1 udp ...", "sdpMLineIndex" => 0}

      assert {:ok, ^candidate} = SignalValidation.validate_candidate(candidate)
    end

    test "drops keys the input did not carry" do
      assert {:ok, validated} =
               SignalValidation.validate_candidate(%{
                 "candidate" => "candidate:1 1 udp ...",
                 "sdpMid" => "0",
                 "sdpMLineIndex" => nil
               })

      refute Map.has_key?(validated, "sdpMLineIndex")
    end

    test "ignores keys that are not part of the signal" do
      assert {:ok, validated} =
               SignalValidation.validate_candidate(%{
                 "candidate" => "candidate:1 1 udp ...",
                 "sdpMid" => "0",
                 "usernameFragment" => "smuggled"
               })

      assert validated == %{"candidate" => "candidate:1 1 udp ...", "sdpMid" => "0"}
    end

    test "refuses a candidate naming neither a media section nor an index" do
      assert {:error, :invalid_signal} =
               SignalValidation.validate_candidate(%{"candidate" => "candidate:1 1 udp ..."})
    end

    test "accepts candidate text at the bound and refuses one byte past it" do
      at_bound = %{"candidate" => String.duplicate("a", 4_096), "sdpMid" => "0"}
      past_bound = %{"candidate" => String.duplicate("a", 4_097), "sdpMid" => "0"}

      assert {:ok, _candidate} = SignalValidation.validate_candidate(at_bound)
      assert {:error, :invalid_signal} = SignalValidation.validate_candidate(past_bound)
    end

    test "accepts a media section id at the bound and refuses one byte past it" do
      at_bound = %{"candidate" => "candidate:1", "sdpMid" => String.duplicate("m", 64)}
      past_bound = %{"candidate" => "candidate:1", "sdpMid" => String.duplicate("m", 65)}

      assert {:ok, _candidate} = SignalValidation.validate_candidate(at_bound)
      assert {:error, :invalid_signal} = SignalValidation.validate_candidate(past_bound)
    end

    test "refuses an index that is negative, past the bound or not an integer" do
      for index <- [-1, 128, 1_000, "0", 1.5] do
        assert {:error, :invalid_signal} =
                 SignalValidation.validate_candidate(%{
                   "candidate" => "candidate:1",
                   "sdpMLineIndex" => index
                 })
      end
    end

    test "accepts the highest index inside the bound" do
      assert {:ok, _candidate} =
               SignalValidation.validate_candidate(%{
                 "candidate" => "candidate:1",
                 "sdpMLineIndex" => 127
               })
    end

    test "refuses empty candidate text and anything that is not a map" do
      assert {:error, :invalid_signal} =
               SignalValidation.validate_candidate(%{"candidate" => "", "sdpMid" => "0"})

      for value <- [nil, "candidate:1 1 udp ...", 42, []] do
        assert {:error, :invalid_signal} = SignalValidation.validate_candidate(value)
      end
    end
  end

  describe "validate_offer_id/1" do
    test "accepts an identifier" do
      assert {:ok, "p2p-2-1"} = SignalValidation.validate_offer_id("p2p-2-1")
    end

    test "reports an absent identifier apart from a malformed one" do
      assert {:ok, nil} = SignalValidation.validate_offer_id(nil)
      assert {:error, :invalid_signal} = SignalValidation.validate_offer_id("")
    end

    test "accepts one at the bound and refuses one byte past it" do
      assert {:ok, _id} = SignalValidation.validate_offer_id(String.duplicate("a", 80))

      assert {:error, :invalid_signal} =
               SignalValidation.validate_offer_id(String.duplicate("a", 81))
    end

    test "refuses a non-binary identifier" do
      for value <- [42, %{}, [], true] do
        assert {:error, :invalid_signal} = SignalValidation.validate_offer_id(value)
      end
    end
  end
end
