defmodule RetroHexChatWeb.Components.UI.MentionBadge do
  @moduledoc """
  How many of the new messages in a conversation are about you.

  A separate number from the unread count on purpose. "There is something new
  here" and "somebody is asking you something" are different questions, and one
  badge answering both is a badge you have to open the conversation to
  interpret — which is exactly the work the badge exists to save.

  It is the badge primitive, not a second small box: the retro inset and the
  eleven-pixel type belong to one component, and a look-alike drifts from it
  the first time either changes.

  ## Usage

      <.mention_badge count={3} testid="channel-mention-badge-#lobby" />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Badge

  alias RetroHexChat.Chat.UnreadTracker

  @doc "Renders the mention count, or nothing at all when there is none."
  attr :count, :integer, default: 0
  attr :testid, :string, default: nil
  attr :class, :any, default: nil

  @spec mention_badge(map()) :: Phoenix.LiveView.Rendered.t()
  def mention_badge(assigns) do
    ~H"""
    <.badge
      :if={@count > 0}
      variant="destructive"
      class={classes(["chat-mention-badge", @class])}
      title={dngettext("chat", "%{count} mention", "%{count} mentions", @count)}
      data-testid={@testid}
    >
      {label(@count)}
    </.badge>
    """
  end

  # The "@" is not decoration. Beside the unread count, a bare number reads as
  # the same number twice — "(2) 1 1" — and the whole point of the second badge
  # is that it says something the first one does not.
  @spec label(non_neg_integer()) :: String.t()
  defp label(count), do: "@" <> UnreadTracker.display_count(count)
end
