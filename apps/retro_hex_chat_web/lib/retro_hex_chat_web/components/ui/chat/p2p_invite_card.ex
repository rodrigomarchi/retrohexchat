defmodule RetroHexChatWeb.Components.UI.P2PInviteCard do
  @moduledoc """
  P2P invite card component for the showcase design system.

  Displays a P2P session invite within a chat message, with a label
  and a "Join lobby" link.

  ## Usage

      <.p2p_invite_card label="Voice chat session" link="/p2p/abc123" />
  """
  use RetroHexChatWeb.Component

  @doc "Renders a P2P invite card with label and join link."
  attr :label, :string, required: true, doc: "Invite description text"
  attr :link, :string, required: true, doc: "URL path to the P2P lobby"
  attr :class, :any, default: nil
  attr :rest, :global

  @spec p2p_invite_card(map()) :: Phoenix.LiveView.Rendered.t()
  def p2p_invite_card(assigns) do
    ~H"""
    <span class={@class} data-testid="p2p-invite-card" {@rest}>
      {@label}
      <a
        href={@link}
        class="underline font-bold ml-1"
        target="_blank"
        rel="noopener noreferrer"
      >
        {gettext("Join lobby")}
      </a>
    </span>
    """
  end
end
