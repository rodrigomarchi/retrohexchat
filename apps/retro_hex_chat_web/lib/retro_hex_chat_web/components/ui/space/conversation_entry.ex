defmodule RetroHexChatWeb.Components.UI.Space.ConversationEntry do
  @moduledoc """
  The control that puts this conversation's space into the conversation.

  One shape and no second, which is the whole point: the entry does not go
  anywhere. Pressing it writes the space's card into the channel or the private
  message, and that card is the door — for the person who pressed it exactly as
  for everybody else reading.

  Two doors into one room is what this used to be, and the anchor was the one
  that skipped the conversation: somebody walked into a space nobody was told
  about. It carries no count for the same reason it carries no address — how
  many people are inside is on the card, which has a feed for exactly that.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  attr :space_id, :string, required: true
  attr :identified, :boolean, default: true
  attr :class, :any, default: nil

  @spec space_conversation_entry(map()) :: Phoenix.LiveView.Rendered.t()
  def space_conversation_entry(assigns) do
    ~H"""
    <div class={classes(["conversation-toolbar-entry flex items-center gap-px", @class])}>
      <button
        type="button"
        phx-click="space_open"
        disabled={!@identified}
        class={[
          "conversation-toolbar-button flex shrink-0 items-center justify-center shadow-retro-raised bg-surface text-xs",
          "focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground",
          !@identified && "opacity-60"
        ]}
        title={title(@identified)}
        data-testid="space-open"
        data-space={@space_id}
      >
        <Icons.icon_toolbar_community class="h-3.5 w-3.5 shrink-0" />
        <span class="conversation-toolbar-button__text">{dgettext("chat", "Space")}</span>
      </button>
    </div>
    """
  end

  # A card carries who is accountable for the address on it, so minting one is
  # a registered nickname's move. Saying that before the click is the honest
  # shape: the alternative is a control that answers every press with a refusal.
  defp title(true), do: dgettext("chat", "Put the space card in this conversation")

  defp title(false),
    do: dgettext("chat", "Register your nickname to put the space card here")
end
