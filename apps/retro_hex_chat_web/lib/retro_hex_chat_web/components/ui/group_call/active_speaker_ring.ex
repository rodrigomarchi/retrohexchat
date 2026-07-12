defmodule RetroHexChatWeb.Components.UI.GroupCall.ActiveSpeakerRing do
  @moduledoc """
  Small active-speaker indicator used beside participant identity.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  attr :participant_id, :any, required: true
  attr :active, :boolean, default: false

  @spec active_speaker_badge(map()) :: Phoenix.LiveView.Rendered.t()
  def active_speaker_badge(assigns) do
    ~H"""
    <span
      :if={@active}
      class="inline-flex h-4 items-center gap-1 border border-primary bg-primary/10 px-1 text-[9px] font-bold uppercase leading-none text-primary"
      title={dgettext("group_call", "Speaking now")}
      aria-label={dgettext("group_call", "Speaking now")}
      data-testid={"group-call-participant-active-speaker-#{@participant_id}"}
      data-group-call-active-speaker
    >
      <Icons.icon_microphone class="h-2.5 w-2.5" />
      {dgettext("group_call", "Speaking")}
    </span>
    """
  end
end
