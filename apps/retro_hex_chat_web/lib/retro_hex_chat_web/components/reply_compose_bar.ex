defmodule RetroHexChatWeb.Components.ReplyComposeBar do
  @moduledoc """
  Reply compose bar showing "Respondendo a {author} — {preview} ✕" above the chat input.
  """
  use Phoenix.Component

  attr :reply_to, :map, default: nil

  @spec reply_compose_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def reply_compose_bar(assigns) do
    ~H"""
    <div
      :if={@reply_to}
      class="reply-compose-bar"
      role="status"
      aria-live="polite"
      data-testid="reply-compose-bar"
    >
      <span class="reply-compose-bar__text">
        Replying to <span class="reply-compose-bar__author">{@reply_to.author}</span>
        — {@reply_to.preview}
      </span>
      <button
        class="reply-compose-bar__dismiss"
        phx-click="cancel_reply"
        tabindex="0"
        aria-label="Cancel reply"
        data-testid="cancel-reply"
      >
        ✕
      </button>
    </div>
    """
  end
end
