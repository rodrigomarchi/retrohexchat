defmodule RetroHexChatWeb.ChatLive.Components.ComposerVoiceRecordingTest do
  @moduledoc """
  What the composer keeps of a recording's announcement, and the words it says
  when one is refused or cannot be made. The events that reach these functions,
  and what a recording becomes once it lands, are `ChatLive.VoiceMessageTest`'s.
  """
  use ExUnit.Case, async: true

  alias RetroHexChatWeb.ChatLive.Components.Composer

  @moduletag :unit

  @target {:channel, "#voice"}

  defp announce(filename, extra \\ %{}), do: announce_into(%{}, filename, extra)

  defp announce_into(recordings, filename, extra \\ %{}) do
    params =
      Map.merge(
        %{
          "filename" => filename,
          "duration_ms" => 4_200,
          "content_type" => "audio/webm;codecs=opus"
        },
        extra
      )

    Composer.put_voice_recording(recordings, params, @target)
  end

  test "a finished recording is kept with its length, bound for where it was made" do
    assert {:ok, %{"voice-20260927-101500.weba" => recording}} =
             announce("voice-20260927-101500.weba", %{"duration_ms" => 7_400})

    assert recording == %{metadata: %{"voice" => true, "duration_ms" => 7_400}, target: @target}
  end

  test "a length past the ceiling is cut down to it" do
    assert {:ok, %{"voice-20260927-101501.weba" => %{metadata: metadata}}} =
             announce("voice-20260927-101501.weba", %{
               "duration_ms" => 90_000,
               "content_type" => "audio/webm"
             })

    assert metadata == %{"voice" => true, "duration_ms" => 60_000}
  end

  test "a recording in an impossible format is refused" do
    assert {:error, message} =
             announce("voice-20260927-101502.weba", %{"content_type" => "application/zip"})

    assert message =~ "format"
  end

  test "an announcement under a name no recorder here produces is refused" do
    for filename <- ["notes.weba", "voice-2026.exe", String.duplicate("a", 5_000), 42] do
      assert {:error, message} = announce(filename)
      assert message =~ "upload failed"
    end
  end

  test "announcements are bounded by the recordings that may upload at once" do
    recordings =
      Enum.reduce(10..15, %{}, fn second, recordings ->
        case announce_into(recordings, "voice-20261006-1645#{second}.weba") do
          {:ok, recordings} ->
            recordings

          {:error, message} ->
            assert message =~ "Too many"
            recordings
        end
      end)

    assert map_size(recordings) == 3
  end

  test "a malformed announcement is refused in words" do
    assert {:error, message} = Composer.put_voice_recording(%{}, %{}, @target)
    assert message =~ "upload failed"
  end

  test "a microphone the browser refused is worded by the composer" do
    assert Composer.voice_error_message("denied") =~ "microphone"
  end

  test "a microphone the machine cannot provide is not called a refusal" do
    assert Composer.voice_error_message("unavailable") =~ "No microphone"
  end

  test "any other failure says the browser cannot record" do
    assert Composer.voice_error_message(nil) =~ "record"
  end
end
