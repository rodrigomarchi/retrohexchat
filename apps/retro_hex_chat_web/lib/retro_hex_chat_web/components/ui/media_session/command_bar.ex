defmodule RetroHexChatWeb.Components.UI.MediaSession.CommandBar do
  @moduledoc """
  Shared command-bar shell for media-session action groups.

  The component owns only toolbar/group semantics and layout chrome. Callers
  keep button events, labels, state, permissions, hooks, and data attributes.
  """
  use RetroHexChatWeb.Component

  attr :aria_label, :string, required: true
  attr :role, :string, values: ~w(toolbar group), default: "toolbar"

  attr :class, :any,
    default:
      "flex shrink-0 flex-wrap items-center justify-center gap-1 border border-border bg-surface px-1 py-1 shadow-retro-sunken"

  attr :testid, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  @spec media_session_command_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def media_session_command_bar(assigns) do
    ~H"""
    <div
      class={classes([@class])}
      role={@role}
      aria-label={@aria_label}
      data-testid={@testid}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end
end
