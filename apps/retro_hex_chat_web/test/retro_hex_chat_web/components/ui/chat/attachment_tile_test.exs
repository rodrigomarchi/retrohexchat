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
    assert length_text(html) == "--:--"
  end

  defp length_text(html) do
    html
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("[data-testid=message-voice-duration]")
    |> LazyHTML.text()
  end

  describe "a file that plays" do
    defp video do
      voice(%{id: 9, filename: "clip.mp4", preview_kind: "video", preview_metadata: %{}})
    end

    # One look for everything that plays: the Hex device, never the
    # browser's own controls, which differ from one browser to the next.
    test "plays in the Hex player, without the browser's controls" do
      for attachment <- [voice(), video(), voice(%{filename: "song.mp3", preview_metadata: %{}})] do
        html = render_component(&attachment_tile/1, attachment: attachment)

        assert html =~ ~s(phx-hook="HexPlayerHook")
        assert html =~ ~s(data-testid="hex-player-play")
        refute html =~ ~r/<(audio|video)[^>]*\bcontrols\b/
      end
    end

    test "a video gets a screen and a key to fill the screen; a sound gets a spectrum" do
      video_html = render_component(&attachment_tile/1, attachment: video())
      assert video_html =~ "<video"
      assert video_html =~ ~s(data-testid="hex-player-fullscreen")
      refute video_html =~ "data-player-scope"

      sound_html = render_component(&attachment_tile/1, attachment: voice())
      assert sound_html =~ "data-player-scope"
      refute sound_html =~ ~s(data-testid="hex-player-fullscreen")
    end

    # The same line is drawn in the conversation and in its thread at once.
    test "the same file has a player of its own in each place it is drawn" do
      chat = render_component(&attachment_tile/1, attachment: video())
      thread = render_component(&attachment_tile/1, attachment: video(), scope: "thread")

      assert chat =~ ~s(id="hex-player-chat-9")
      assert thread =~ ~s(id="hex-player-thread-9")
    end
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

  describe "a picture" do
    defp picture do
      %{
        id: 7,
        filename: "night-city.png",
        byte_size: 57_651,
        directory_path: "/chat/channels/lobby/2026/10/29/Ana",
        logical_path: "/chat/channels/lobby/2026/10/29/Ana/night-city.png",
        preview_kind: "image",
        preview_status: "ready"
      }
    end

    # The picture is the content; its file name and size are what the file
    # manager says about it. They stay for whoever points at it or reads it
    # aloud, not as a title bar over every photo.
    test "is drawn without a title bar, and still says its name and size" do
      doc =
        render_component(&attachment_tile/1, attachment: picture()) |> LazyHTML.from_fragment()

      [tile] = doc |> LazyHTML.query("[data-testid=message-attachment]") |> Enum.to_list()

      refute LazyHTML.text(tile) =~ "night-city.png"
      assert [label] = LazyHTML.attribute(tile, "aria-label")
      assert label =~ "night-city.png"
      assert label =~ "56.3 KB"
      assert doc |> LazyHTML.query("img[alt='night-city.png']") |> Enum.count() == 1
    end
  end
end
