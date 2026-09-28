defmodule RetroHexChatWeb.ChatLive.VoiceMessageTest do
  @moduledoc """
  Recording from the composer.

  Two facts are under test and neither is the audio. The first is where the
  strip is offered: on a phone, which is where somebody speaks a message instead
  of typing it — on a desktop the file picker was always the better answer, and
  a control that exists everywhere would make that decision meaningless. The
  second is the length, which reaches the server in the one moment it can be
  written beside the file, and is refused along with anything else arriving
  under a content type a recording cannot have.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive.Components.Composer

  setup ctx do
    owner = register("Voi")
    channel = "#voi#{uid()}"

    {:ok, view, _html} = ctx.conn |> chat_conn(owner, pre_identified: true) |> live(~p"/chat")
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

  defp go_mobile(view) do
    render_hook(view, "viewport_info", %{"width" => 393, "mobile" => true})
  end

  # Absence: a desktop is offered nothing, and the hook that would ask for a
  # microphone is never mounted there.
  test "the strip is not in the composer on a desktop", ctx do
    html = render(ctx.view)

    refute html =~ ~s(data-testid="voice-recorder")
    refute html =~ "VoiceRecorderHook"
  end

  test "the strip is in the composer on a phone", ctx do
    go_mobile(ctx.view)
    html = render(ctx.view)

    assert html =~ ~s(data-testid="voice-recorder")
    assert html =~ "VoiceRecorderHook"
    assert html =~ ~s(phx-update="ignore")
    assert html =~ ~s(data-voice-action="start")
    assert html =~ ~s(data-voice-action="stop")
    assert html =~ ~s(data-voice-action="cancel")
  end

  test "a finished recording hands the composer its length", ctx do
    go_mobile(ctx.view)

    render_hook(strip(ctx.view), "voice_recorded", %{
      "filename" => "voice-20260927-101500.weba",
      "duration_ms" => 7_400,
      "content_type" => "audio/webm;codecs=opus"
    })

    assert composer_state(ctx.view).voice_recordings == %{
             "voice-20260927-101500.weba" => %{"voice" => true, "duration_ms" => 7_400}
           }
  end

  test "a length past the ceiling is cut down to it", ctx do
    go_mobile(ctx.view)

    render_hook(strip(ctx.view), "voice_recorded", %{
      "filename" => "voice-long.weba",
      "duration_ms" => 90_000,
      "content_type" => "audio/webm"
    })

    assert composer_state(ctx.view).voice_recordings == %{
             "voice-long.weba" => %{"voice" => true, "duration_ms" => 60_000}
           }
  end

  # Absence: a content type a recording cannot have keeps nothing at all, and
  # says so where the composer says everything else.
  test "a recording in an impossible format is refused", ctx do
    go_mobile(ctx.view)

    render_hook(strip(ctx.view), "voice_recorded", %{
      "filename" => "voice-trojan.zip",
      "duration_ms" => 1_000,
      "content_type" => "application/zip"
    })

    state = composer_state(ctx.view)

    assert state.voice_recordings == %{}
    assert state.input_error =~ "format"
  end

  defp strip(view), do: element(view, "#voice-recorder")

  defp register(prefix) do
    nickname = "#{prefix}#{uid()}"
    {:ok, _} = NickServ.register(nickname, "password123")
    nickname
  end
end
