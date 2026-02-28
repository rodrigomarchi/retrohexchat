defmodule RetroHexChatWeb.Components.UI.TypingIndicator do
  @moduledoc """
  Typing indicator component for the showcase design system.

  Shows a "{nick} is typing..." message in PM conversations.
  Only renders when a nick is provided (non-nil).

  ## Usage

      <.typing_indicator nick={@pm_typing_from} />
  """
  use RetroHexChatWeb.Component

  @doc "Renders a typing indicator bar."
  attr :nick, :string, default: nil, doc: "Nickname of the user who is typing"
  attr :class, :any, default: nil
  attr :rest, :global

  @spec typing_indicator(map()) :: Phoenix.LiveView.Rendered.t()
  def typing_indicator(assigns) do
    ~H"""
    <div
      :if={@nick}
      class={classes(["px-2 py-0.5 text-xs text-muted-foreground italic", @class])}
      data-testid="typing-indicator"
      {@rest}
    >
      {@nick} is typing...
    </div>
    """
  end
end
