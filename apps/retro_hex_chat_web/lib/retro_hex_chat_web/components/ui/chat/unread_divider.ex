defmodule RetroHexChatWeb.Components.UI.UnreadDivider do
  @moduledoc """
  The line that says "everything below this is new".

  Drawn *inside* the row that follows the last message the reader had seen,
  rather than inserted into the stream as a row of its own. Two reasons, and
  either alone would settle it: a stream container requires an id on every one
  of its children, and a synthetic row would reorder with the messages around it
  and be pruned by the stream's negative `limit:` — which is exactly what
  removes the rows a prepend has just added.

  ## Usage

      <.unread_divider :if={@msg.id == @unread_boundary_id} />
  """
  use RetroHexChatWeb.Component

  @doc "Renders the new-messages rule."
  attr :class, :any, default: nil

  @spec unread_divider(map()) :: Phoenix.LiveView.Rendered.t()
  def unread_divider(assigns) do
    ~H"""
    <div
      class={classes(["unread-divider", @class])}
      role="separator"
      aria-label={dgettext("chat", "New messages")}
      data-testid="unread-divider"
    >
      <span class="unread-divider__label">{dgettext("chat", "New messages")}</span>
    </div>
    """
  end
end
