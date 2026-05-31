defmodule RetroHexChatWeb.Components.UI.MessageIndicators do
  @moduledoc """
  Small indicator components for chat messages in the showcase design system.

  Provides `edited_tag/1`, `deleted_placeholder/1`, and `retry_button/1`
  for inline message status indicators.

  ## Usage

      <.edited_tag timestamp="14:30 28/02/2026" />
      <.deleted_placeholder />
      <.retry_button temp_id="abc" content="Hello" target="#lobby" on_retry="retry_message" />
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  @doc "Renders an (edited) tag with tooltip showing the edit timestamp."
  attr :timestamp, :string, required: true, doc: "Formatted edit timestamp for the title tooltip"
  attr :class, :any, default: nil
  attr :rest, :global

  @spec edited_tag(map()) :: Phoenix.LiveView.Rendered.t()
  def edited_tag(assigns) do
    ~H"""
    <span
      class={classes(["text-[10px] text-muted-foreground ml-1", @class])}
      title={dgettext("chat", "Edited at %{timestamp}", timestamp: @timestamp)}
      data-testid="edited-tag"
      {@rest}
    >
      {dgettext("chat", "(edited)")}
    </span>
    """
  end

  @doc "Renders a [message deleted] placeholder."
  attr :class, :any, default: nil
  attr :rest, :global

  @spec deleted_placeholder(map()) :: Phoenix.LiveView.Rendered.t()
  def deleted_placeholder(assigns) do
    ~H"""
    <span
      class={classes(["italic text-muted-foreground", @class])}
      data-testid="deleted-message"
      {@rest}
    >
      {dgettext("chat", "[message deleted]")}
    </span>
    """
  end

  @doc "Renders a retry button for failed messages."
  attr :temp_id, :string, required: true, doc: "Temporary message ID"
  attr :content, :string, required: true, doc: "Original message content"
  attr :target, :string, default: "", doc: "Target channel or PM nick"
  attr :on_retry, :any, default: nil, doc: "Event name for retry click"
  attr :class, :any, default: nil
  attr :rest, :global

  @spec retry_button(map()) :: Phoenix.LiveView.Rendered.t()
  def retry_button(assigns) do
    ~H"""
    <button
      class={classes(["text-destructive text-xs ml-1", @class])}
      phx-click={@on_retry}
      phx-value-temp_id={@temp_id}
      phx-value-content={@content}
      phx-value-target={@target}
      title={dgettext("chat", "Failed to send. Click to retry")}
      data-testid="retry-message"
      {@rest}
    >
      <Icons.icon_warning class="w-3 h-3 inline-block" />
    </button>
    """
  end
end
