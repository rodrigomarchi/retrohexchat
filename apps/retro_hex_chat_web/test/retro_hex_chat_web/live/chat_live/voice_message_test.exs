defmodule RetroHexChatWeb.ChatLive.VoiceMessageTest do
  @moduledoc """
  Recording from the composer.

  Three facts are under test and none of them is the audio. The first is the
  announcement — the length, the name and the content type a recording may
  carry, refused along with anything a recorder here could not have produced,
  and bounded in number; every rule of it is `ComposerVoiceRecordingTest`'s,
  and here only that the recorder's events reach it. The second is what a recording is once it lands: a
  message of its own, sent at once, carrying nothing that was typed and leaving
  the draft where it was. The third is where it goes: to the conversation it
  was recorded in, even when the reader has moved on.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  @form "#chat-input-area form"

  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive.Components.Composer

  setup ctx do
    owner = register("Voi")
    channel = "#voi#{uid()}"

    {:ok, view, _html} = ctx.conn |> chat_conn(owner, pre_identified: true) |> live("/")
    submit_command_sync(view, "/join #{channel}")

    %{view: view, owner: owner, channel: channel}
  end

  # The island's own assigns, read the way the other island tests read them.
  defp composer_state(view) do
    {components, _ids, _uuid} = view.pid |> :sys.get_state() |> Map.fetch!(:components)

    Enum.find_value(components, fn
      {_cid, {Composer, _id, assigns, _private, _prints}} -> assigns
      _other -> nil
    end)
  end

  test "a finished recording hands the composer its length", ctx do
    render_hook(strip(ctx.view), "voice_recorded", %{
      "filename" => "voice-20260927-101500.weba",
      "duration_ms" => 7_400,
      "content_type" => "audio/webm;codecs=opus"
    })

    assert %{"voice-20260927-101500.weba" => %{metadata: metadata}} =
             composer_state(ctx.view).voice_recordings

    assert metadata == %{"voice" => true, "duration_ms" => 7_400}
  end

  # The whole point of a voice message: it goes on its own. Whatever is typed
  # stays in the input, and the message carries only the recording.
  test "a recording is sent the moment it lands, as a message of its own", ctx do
    ctx.view |> element(@form) |> render_change(%{"input" => "still typing this"})
    upload = announce_and_select(ctx.view, "voice-20261006-164500.weba")

    assert render_upload(upload, "voice-20261006-164500.weba") =~ "chat-input"

    message = latest_message(ctx.channel)

    assert message.content == ""
    assert [%{file: file}] = message.attachments
    assert file.preview_metadata == %{"voice" => true, "duration_ms" => 4_200}

    state = composer_state(ctx.view)
    assert state.input == "still typing this"
    assert state.voice_recordings == %{}
    assert state.uploads.voice.entries == []
  end

  # Absence: a file that reaches the recording upload without having been
  # recorded here is refused before it is stored, and nothing is sent.
  test "an upload nobody announced as a recording is refused", ctx do
    upload =
      file_input(ctx.view, @form, :voice, [
        %{name: "smuggled.weba", content: "audio", type: "audio/webm"}
      ])

    render_upload(upload, "smuggled.weba")

    assert latest_message(ctx.channel) == nil
  end

  # Absence: a malformed event is refused in words, never by taking the page
  # down with it. Which words, for every refusal and every recorder failure, is
  # `ComposerVoiceRecordingTest`'s; this is that both events reach them.
  test "malformed recorder events leave the chat standing", ctx do
    render_hook(strip(ctx.view), "voice_recorded", %{})
    assert composer_state(ctx.view).input_error =~ "upload failed"

    render_hook(strip(ctx.view), "voice_error", %{})

    assert Process.alive?(ctx.view.pid)
    assert composer_state(ctx.view).input_error =~ "record"
  end

  # Absence: something announced as a recording but arriving as another kind
  # of file is refused before it is stored.
  test "a recording upload that is not audio is refused", ctx do
    announce(ctx.view, "voice-20261006-164501.weba")

    upload =
      file_input(ctx.view, @form, :voice, [
        %{name: "voice-20261006-164501.weba", content: "MZ", type: "application/x-msdownload"}
      ])

    render_upload(upload, "voice-20261006-164501.weba")

    assert latest_message(ctx.channel) == nil
  end

  test "cancelling an upload forgets its announcement", ctx do
    upload = announce_and_select(ctx.view, "voice-20261006-164502.weba")
    render_upload(upload, "voice-20261006-164502.weba", 50)

    [entry] = composer_state(ctx.view).uploads.voice.entries
    render_click(element(ctx.view, ~s([phx-click="cancel_voice_upload"])), %{"ref" => entry.ref})

    assert composer_state(ctx.view).voice_recordings == %{}
    assert latest_message(ctx.channel) == nil
  end

  # Send was pressed in one channel; the upload lands after the reader opened
  # another. The recording belongs where it was made.
  test "a recording lands in the conversation it was recorded in", ctx do
    upload = announce_and_select(ctx.view, "voice-20261006-164503.weba")
    other = "#voo#{uid()}"
    submit_command_sync(ctx.view, "/join #{other}")

    render_upload(upload, "voice-20261006-164503.weba")

    assert [%{file: %{preview_metadata: %{"voice" => true}}}] =
             latest_message(ctx.channel).attachments

    assert latest_message(other) == nil
  end

  test "a recording made in a private conversation is sent there", ctx do
    peer = register("Pee")
    render_click(ctx.view, "context_query", %{"nick" => peer})
    upload = announce_and_select(ctx.view, "voice-20261006-164504.weba")

    render_upload(upload, "voice-20261006-164504.weba")

    [message] =
      ctx.owner
      |> Queries.list_private_messages(peer, limit: 5)
      |> Map.fetch!(:items)
      |> Enum.map(&Queries.preload_attachments/1)

    assert message.content == ""
    assert [%{file: %{preview_metadata: %{"voice" => true}}}] = message.attachments
  end

  defp announce(view, filename) do
    render_hook(strip(view), "voice_recorded", %{
      "filename" => filename,
      "duration_ms" => 4_200,
      "content_type" => "audio/webm;codecs=opus"
    })
  end

  defp announce_and_select(view, filename) do
    render_hook(strip(view), "voice_recorded", %{
      "filename" => filename,
      "duration_ms" => 4_200,
      "content_type" => "audio/webm;codecs=opus"
    })

    file_input(view, @form, :voice, [
      %{name: filename, content: "fake opus", type: "audio/webm"}
    ])
  end

  defp latest_message(channel) do
    channel
    |> Queries.list_messages(limit: 5)
    |> Map.fetch!(:items)
    |> Enum.filter(&(&1.type == "message"))
    |> List.last()
    |> then(&(&1 && Queries.preload_attachments(&1)))
  end

  defp strip(view), do: element(view, "#voice-recorder")

  defp register(prefix) do
    nickname = "#{prefix}#{uid()}"
    {:ok, _} = NickServ.register(nickname, "password123")
    nickname
  end
end
