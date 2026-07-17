defmodule RetroHexChatWeb.Components.UI.MediaSession.ActionButton do
  @moduledoc """
  Shared text action button for media-session alerts and compact command areas.

  This is the labelled counterpart to `MediaSession.IconButton`: visual chrome,
  title, and aria-label only. Callers own events and button contents.
  """
  use RetroHexChatWeb.Component

  attr :label, :string, required: true
  attr :tone, :string, values: ~w(default danger), default: "default"
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(disabled)

  slot :inner_block, required: true

  @spec media_session_action_button(map()) :: Phoenix.LiveView.Rendered.t()
  def media_session_action_button(assigns) do
    ~H"""
    <button
      type="button"
      title={@label}
      aria-label={@label}
      class={media_session_action_button_class(@tone, @class)}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @spec media_session_action_button_class(String.t(), any()) :: String.t()
  def media_session_action_button_class(tone, extra \\ nil) do
    classes([
      "inline-flex h-8 shrink-0 items-center justify-center gap-1 bg-surface px-2 text-[10px] font-bold text-foreground shadow-retro-raised",
      "focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground",
      tone == "danger" && "bg-destructive text-destructive-foreground",
      extra
    ])
  end
end
