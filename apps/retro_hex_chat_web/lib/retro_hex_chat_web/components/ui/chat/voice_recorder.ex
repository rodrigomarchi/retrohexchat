defmodule RetroHexChatWeb.Components.UI.VoiceRecorder do
  @moduledoc """
  The strip under the composer that records a voice message.

  Every word and every control is rendered here, including the three things that
  can go wrong, because the browser is where the recording happens and nothing
  written in JavaScript can be translated. What the client decides is which of
  these elements is showing and what the clock reads — which is why the strip
  carries `phx-update="ignore"`: the composer re-renders on every keystroke, and
  a patch that restored this template mid-take would put the microphone button
  back over a recording still running.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChat.Chat.VoiceMessages
  import RetroHexChatWeb.Components.UI.Button

  import RetroHexChatWeb.Components.UI.ToolButton

  alias RetroHexChatWeb.Icons

  @id "voice-recorder"

  @spec id() :: String.t()
  def id, do: @id

  attr :id, :string, default: @id

  attr :target, :any,
    required: true,
    doc: "the composer component the recording and its upload belong to"

  attr :upload, :string, default: "attachments", doc: "the upload name on that component"

  @doc """
  The microphone, the running clock, and the two ways a take can end.

  The strip starts hidden and the client shows it only where recording is
  possible at all. A button that asks for a microphone and then explains that
  this browser has none is worse than no button: on a desktop, choosing a file
  was always the better answer, which is why this is offered on a phone.
  """
  @spec voice_recorder(map()) :: Phoenix.LiveView.Rendered.t()
  def voice_recorder(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="VoiceRecorderHook"
      phx-update="ignore"
      phx-target={@target}
      data-voice-upload={@upload}
      data-testid="voice-recorder"
      class="chat-voice-strip"
      hidden
    >
      <div data-voice-state="idle" class="flex min-w-0 items-center gap-1">
        <.button
          type="button"
          size="sm"
          data-voice-action="start"
          data-testid="voice-record"
          title={dgettext("chat", "Record a voice message")}
        >
          <:icon><Icons.icon_microphone class="h-4 w-4 shrink-0" /></:icon>
          {dgettext("chat", "Record")}
        </.button>
        <span class="min-w-0 truncate text-muted-foreground">
          {dgettext("chat", "Up to %{seconds} seconds", seconds: VoiceMessages.max_duration_seconds())}
        </span>
      </div>

      <div data-voice-state="recording" class="flex min-w-0 items-center gap-1" hidden>
        <span class="chat-voice-dot" aria-hidden="true"></span>
        <span
          data-voice-elapsed
          data-testid="voice-elapsed"
          class="w-9 shrink-0 tabular-nums font-bold"
        >
          0:00
        </span>
        <.button
          type="button"
          size="sm"
          data-voice-action="stop"
          data-testid="voice-stop"
          title={dgettext("chat", "Finish the recording and attach it")}
        >
          <:icon><Icons.icon_checkmark class="h-4 w-4 shrink-0" /></:icon>
          {dgettext("chat", "Attach")}
        </.button>
        <.tool_button
          label={dgettext("chat", "Discard the recording")}
          size="md"
          data-voice-action="cancel"
          data-testid="voice-cancel"
        >
          <Icons.icon_close class="h-4 w-4" />
        </.tool_button>
      </div>

      <p data-voice-error="denied" class="chat-voice-error" hidden>
        {dgettext("chat", "This browser did not give access to the microphone.")}
      </p>
      <p data-voice-error="unsupported" class="chat-voice-error" hidden>
        {dgettext("chat", "This browser cannot record. Attach an audio file instead.")}
      </p>
    </div>
    """
  end
end
