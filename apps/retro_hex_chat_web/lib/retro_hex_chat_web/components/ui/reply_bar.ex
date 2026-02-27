defmodule RetroHexChatWeb.Components.UI.ReplyBar do
  @moduledoc """
  Reply bar component for the showcase design system.

  Composed from button + flex layout.
  "Replying to {author}" bar with dismiss button and original message preview.

  ## Usage

      <.reply_bar author="alice" message="Hello everyone!" />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  @doc "Renders the reply bar."
  attr :author, :string, required: true
  attr :message, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  @spec reply_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def reply_bar(assigns) do
    ~H"""
    <div
      class={
        classes([
          "flex items-center gap-retro-4 px-retro-4 py-retro-2",
          "bg-surface shadow-retro-raised text-xs",
          @class
        ])
      }
      {@rest}
    >
      <Icons.icon_retry class="w-3 h-3 shrink-0 text-muted-foreground" />
      <span class="font-bold shrink-0">Replying to {" "}{@author}</span>
      <span :if={@message} class="flex-1 truncate text-muted-foreground">
        {@message}
      </span>
      <.button size="icon" variant="ghost" class="w-5 h-5 shrink-0">
        <:icon><Icons.icon_close class="w-3 h-3" /></:icon>
      </.button>
    </div>
    """
  end
end
