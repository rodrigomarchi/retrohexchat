defmodule RetroHexChatWeb.Components.UI.ChatAttachmentTest do
  @moduledoc """
  The tile a recording gets, and the tile it does not get.

  A voice message is an audio file, so the ordinary audio tile would play it
  correctly — and read wrong. What it announces is a filename nobody chose and
  a size nobody cares about, when the two facts a recording has are that it is
  somebody speaking and how long they speak for.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.ChatAttachment

  @moduletag :unit

  defp voice(overrides \\ %{}) do
    Map.merge(
      %{
        id: 42,
        filename: "voice-20260927-101500.weba",
        byte_size: 9_112,
        directory_path: "/chat/channels/lobby/2026/09/27/Ada",
        logical_path: "/chat/channels/lobby/2026/09/27/Ada/voice.weba",
        preview_kind: "audio",
        preview_status: "ready",
        preview_metadata: %{"voice" => true, "duration_ms" => 7_400}
      },
      overrides
    )
  end

  test "a recording reads as one, with its length on the tile" do
    html = render_component(&attachment_tile/1, attachment: voice())

    assert html =~ ~s(data-preview-kind="voice")
    assert html =~ ~s(data-testid="message-voice")
    assert html =~ "0:07"
    assert html =~ ~s(data-testid="message-attachment-audio-preview")
    assert html =~ "/chat/attachments/42/preview"
    assert html =~ "8.9 KB"
  end

  # The filename is a timestamp the recorder made up, and putting it where a
  # person's own words go is how an interface admits it has nothing to say.
  test "a recording shows no filename" do
    html = render_component(&attachment_tile/1, attachment: voice())

    refute html =~ "voice-20260927-101500.weba"
  end

  test "a recording with no length stored says nothing instead of zero" do
    html =
      render_component(&attachment_tile/1,
        attachment: voice(%{preview_metadata: %{"voice" => true}})
      )

    assert html =~ ~s(data-testid="message-voice")
    refute html =~ "0:00"
  end

  # Absence: an ordinary audio file is not a recording, and keeps the tile that
  # names it.
  test "an attached audio file keeps the tile it always had" do
    html =
      render_component(&attachment_tile/1,
        attachment: voice(%{filename: "interview.mp3", preview_metadata: %{}})
      )

    refute html =~ ~s(data-testid="message-voice")
    assert html =~ "interview.mp3"
  end
end
