defmodule RetroHexChatWeb.Components.UI.P2PInviteCard do
  @moduledoc """
  P2P invite card component for the showcase design system.

  The inert fallback for a P2P invite whose session could NOT be resolved —
  the session row no longer exists, so there is nothing to join. The rich,
  actionable card is `SessionCard`; this one only preserves the historical
  line without promising a Join that would fail.

  ## Usage

      <.p2p_invite_card label="Voice chat session" />
  """
  use RetroHexChatWeb.Component

  @doc "Renders the inert P2P invite fallback (unresolvable session)."
  attr :label, :string, required: true, doc: "Invite description text"
  attr :class, :any, default: nil
  attr :rest, :global

  @spec p2p_invite_card(map()) :: Phoenix.LiveView.Rendered.t()
  def p2p_invite_card(assigns) do
    ~H"""
    <span class={@class} data-testid="p2p-invite-card" {@rest}>
      {@label}
      <span class="text-muted-foreground ml-1">
        {dgettext("chat", "(this session is no longer available)")}
      </span>
    </span>
    """
  end
end
