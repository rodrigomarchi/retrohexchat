defmodule RetroHexChatWeb.Components.UI.VoiceRecorder do
  @moduledoc """
  The microphone in the composer toolbar, and the take it starts.

  At rest it is one flat button beside the attachment and formatting buttons.
  While a take runs, the same row trades the input and its Send button for the
  take: the recording dot, the running clock, a way to throw it away and a way
  to send it. A recording is sent on its own, as a message of its own — nothing
  typed rides with it and nothing typed is lost.

  Every word is rendered here, because nothing written in JavaScript can be
  translated. What the client decides is which group is showing and what the
  clock reads; the composer row's CSS hides the input while the take's group is
  shown. That is also why the element carries `phx-update="ignore"`:
  the composer re-renders on every keystroke, and a patch that restored this
  template mid-take would put the microphone back over a recording still
  running.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.ToolButton

  @id "voice-recorder"

  @spec id() :: String.t()
  def id, do: @id

  attr :id, :string, default: @id

  attr :target, :any,
    required: true,
    doc: "the composer component the recording and its upload belong to"

  attr :upload, :string, default: "voice", doc: "the upload name on that component"

  @doc """
  The microphone, and the take: the clock, Discard and Send.

  It starts hidden and the client shows it only where recording is possible at
  all — a button that asks for a microphone and then explains that this browser
  has none is worse than no button.
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
      class="chat-voice"
      hidden
    >
      <span data-voice-state="idle" class="chat-voice-idle">
        <.tool_button
          label={dgettext("chat", "Record a voice message")}
          variant="flat"
          size="sm"
          data-voice-action="start"
          data-testid="voice-record"
        >
          <Icons.icon_microphone class="h-4 w-4" />
        </.tool_button>
      </span>

      <span data-voice-state="recording" class="chat-voice-take" hidden>
        <span class="chat-voice-dot" aria-hidden="true"></span>
        <span data-voice-elapsed data-testid="voice-elapsed" class="chat-voice-clock">0:00</span>
        <span class="chat-voice-caption">{dgettext("chat", "Recording")}</span>
        <.tool_button
          label={dgettext("chat", "Discard the recording")}
          variant="flat"
          size="sm"
          tone="danger-on-hover"
          data-voice-action="cancel"
          data-testid="voice-cancel"
        >
          <Icons.icon_close class="h-4 w-4" />
        </.tool_button>
        <.button
          type="button"
          size="sm"
          class="h-8 px-2"
          data-voice-action="stop"
          data-testid="voice-stop"
          title={dgettext("chat", "Send")}
          aria-label={dgettext("chat", "Send")}
        >
          <:icon><Icons.icon_btn_send class="h-4 w-4" /></:icon>
          <span class="chat-input-send-label">{dgettext("chat", "Send")}</span>
        </.button>
      </span>
    </div>
    """
  end
end
