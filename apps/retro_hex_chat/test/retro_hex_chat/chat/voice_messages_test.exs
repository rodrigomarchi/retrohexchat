defmodule RetroHexChat.Chat.VoiceMessagesTest do
  @moduledoc """
  What a recording is allowed to be.

  A voice message is an attachment like any other, so the only thing the domain
  has to decide about it is what a browser is allowed to hand over: a short
  audio container it can produce and this chat can play back inline. Anything
  else arriving under the name "voice" is a caller getting it wrong, not a new
  format to support.
  """
  use ExUnit.Case, async: true

  alias RetroHexChat.Chat.VoiceMessages

  @moduletag :unit

  describe "content_type?/1" do
    test "accepts the containers a browser records into" do
      for content_type <- VoiceMessages.content_types() do
        assert VoiceMessages.content_type?(content_type)
      end
    end

    test "reads the codec parameter off the type it was given" do
      assert VoiceMessages.content_type?("audio/webm;codecs=opus")
      assert VoiceMessages.content_type?("AUDIO/WEBM")
    end

    # Absence: the list is the whole answer, and a zip named like a recording is
    # still a zip.
    test "refuses anything that is not audio" do
      refute VoiceMessages.content_type?("application/zip")
      refute VoiceMessages.content_type?("video/webm")
      refute VoiceMessages.content_type?("")
      refute VoiceMessages.content_type?(nil)
    end
  end

  describe "metadata/2" do
    test "marks the file as a recording and keeps its length" do
      assert {:ok, metadata} = VoiceMessages.metadata("audio/webm", 7_400)
      assert metadata == %{"voice" => true, "duration_ms" => 7_400}
    end

    test "clamps a length past the ceiling" do
      assert {:ok, %{"duration_ms" => duration}} =
               VoiceMessages.metadata("audio/webm", VoiceMessages.max_duration_ms() + 5_000)

      assert duration == VoiceMessages.max_duration_ms()
    end

    test "keeps no length it cannot read" do
      assert {:ok, metadata} = VoiceMessages.metadata("audio/webm", nil)
      assert metadata == %{"voice" => true}

      assert {:ok, %{"voice" => true} = negative} = VoiceMessages.metadata("audio/webm", -3)
      refute Map.has_key?(negative, "duration_ms")
    end

    test "refuses a content type outside the list" do
      assert {:error, :unsupported_content_type} =
               VoiceMessages.metadata("application/zip", 1_000)
    end
  end

  describe "voice?/1 and duration_ms/1" do
    test "read a row that came back from the database with string keys" do
      attachment = %{preview_metadata: %{"voice" => true, "duration_ms" => 3_200}}

      assert VoiceMessages.voice?(attachment)
      assert VoiceMessages.duration_ms(attachment) == 3_200
    end

    test "say no for an ordinary attachment" do
      refute VoiceMessages.voice?(%{preview_metadata: %{}})
      refute VoiceMessages.voice?(%{})
      assert VoiceMessages.duration_ms(%{preview_metadata: %{}}) == nil
    end
  end
end
