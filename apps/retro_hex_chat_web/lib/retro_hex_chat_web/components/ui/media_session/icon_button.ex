defmodule RetroHexChatWeb.Components.UI.MediaSession.IconButton do
  @moduledoc """
  Shared icon-only action button for media-session surfaces.

  This component owns only visual button chrome and ARIA plumbing. Callers keep
  all events, state transitions, permissions, and feature-specific labels.
  """
  use RetroHexChatWeb.Component

  attr :label, :string, required: true
  attr :active, :boolean, default: false
  attr :pressed, :any, default: nil
  attr :tone, :string, values: ~w(default danger), default: "default"
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(disabled)

  slot :inner_block, required: true

  @spec media_session_icon_button(map()) :: Phoenix.LiveView.Rendered.t()
  def media_session_icon_button(assigns) do
    ~H"""
    <button
      type="button"
      title={@label}
      aria-label={@label}
      aria-pressed={media_session_aria_pressed(@pressed)}
      class={media_session_icon_button_class(@active, @tone, @class)}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @spec media_session_icon_button_class(boolean(), String.t(), any()) :: String.t()
  def media_session_icon_button_class(active?, tone, extra \\ nil) do
    classes([
      "inline-flex h-9 w-9 min-w-9 cursor-pointer items-center justify-center border border-transparent bg-surface p-0 shadow-retro-raised",
      "[&>svg]:h-6 [&>svg]:w-6 [&>svg]:shrink-0",
      "focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground",
      active? && "bg-muted shadow-retro-sunken",
      tone == "danger" && "bg-destructive text-destructive-foreground",
      extra
    ])
  end

  defp media_session_aria_pressed(nil), do: nil
  defp media_session_aria_pressed(value) when is_binary(value), do: value
  defp media_session_aria_pressed(value), do: to_string(value)
end
