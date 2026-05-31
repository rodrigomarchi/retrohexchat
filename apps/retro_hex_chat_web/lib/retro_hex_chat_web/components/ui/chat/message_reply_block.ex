defmodule RetroHexChatWeb.Components.UI.MessageReplyBlock do
  @moduledoc """
  Reply-to indicator for chat messages in the showcase design system.

  Shows "replying to {author}: {preview}" above a message, with click-to-scroll
  functionality to navigate to the parent message.

  ## Usage

      <.message_reply_block
        parent_id="msg-123"
        author="alice"
        preview="Hello world!"
        nick_color="nick-color-3"
        on_click="scroll_to_reply_parent"
      />
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  @doc "Renders a reply-to indicator block above a message."
  attr :parent_id, :string, required: true, doc: "ID of the parent message to scroll to"
  attr :author, :string, default: "?", doc: "Author of the parent message"
  attr :preview, :string, default: nil, doc: "Preview text of the parent message (nil if deleted)"
  attr :nick_color, :string, default: nil, doc: "CSS class for the author nick color"
  attr :on_click, :any, default: nil, doc: "Event name for click-to-scroll"
  attr :class, :any, default: nil
  attr :rest, :global

  @spec message_reply_block(map()) :: Phoenix.LiveView.Rendered.t()
  def message_reply_block(assigns) do
    ~H"""
    <div
      class={
        classes([
          "flex gap-1 items-center text-xs text-muted-foreground pl-2 cursor-pointer hover:bg-surface-hover",
          @class
        ])
      }
      phx-click={@on_click}
      phx-value-parent_id={@parent_id}
      role="link"
      aria-label={dgettext("chat", "Replying to %{author}", author: @author)}
      data-testid="reply-block"
      {@rest}
    >
      <Icons.icon_btn_prev class="w-3 h-3 rotate-180" />
      <span class={@nick_color}>{@author}</span>
      <span :if={@preview} class="truncate">{@preview}</span>
      <span :if={!@preview} class="italic">{dgettext("chat", "[message deleted]")}</span>
    </div>
    """
  end
end
