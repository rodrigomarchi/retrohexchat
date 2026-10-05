defmodule RetroHexChatWeb.Components.UI.MediaSession.Dock do
  @moduledoc """
  Translucent toolbar laid over the bottom of a call's video.

  The caller places it inside the stage and gives that stage the
  `media-dock-host` class; the dock fades while the pointer is away from the
  stage and comes back on hover or focus (`media-session-dock.css`). The host
  also publishes `--media-dock-clearance`, the height of edge the dock covers. Callers
  keep the buttons, their events and their state — the dock owns only the
  toolbar semantics and the chrome.
  """
  use RetroHexChatWeb.Component

  attr :aria_label, :string, required: true
  attr :testid, :string, default: nil
  attr :compact, :boolean, default: false, doc: "tighter buttons for a mini window"
  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  @spec media_session_dock(map()) :: Phoenix.LiveView.Rendered.t()
  def media_session_dock(assigns) do
    ~H"""
    <div
      class={classes(["media-dock", @compact && "media-dock--compact", @class])}
      role="toolbar"
      aria-label={@aria_label}
      data-testid={@testid}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "A thin bevelled divider between groups of dock buttons."
  @spec media_session_dock_separator(map()) :: Phoenix.LiveView.Rendered.t()
  def media_session_dock_separator(assigns) do
    ~H"""
    <span class="media-dock__separator" aria-hidden="true"></span>
    """
  end
end
