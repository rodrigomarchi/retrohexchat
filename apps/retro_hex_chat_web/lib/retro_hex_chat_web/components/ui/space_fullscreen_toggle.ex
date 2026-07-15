defmodule RetroHexChatWeb.Components.UI.SpaceFullscreenToggle do
  @moduledoc """
  Translucent fullscreen toggle for the virtual space, anchored to the
  top-right corner of the space canvas. The same button exits back to the
  normal layout (and stays in sync when fullscreen ends via Esc).

  Pure static markup inside the `phx-update="ignore"` space shell — the
  Fullscreen API calls and state sync live in
  `assets/js/lib/space/fullscreen.js`, which toggles the `data-fullscreen`
  attribute this markup styles against (`group-data-[fullscreen]:` swaps the
  enter/exit glyph). `tabindex="-1"` keeps the button pointer-only, like the
  virtual pad.
  """
  use RetroHexChatWeb, :html

  alias RetroHexChatWeb.Icons

  @spec space_fullscreen_toggle(map()) :: Phoenix.LiveView.Rendered.t()
  def space_fullscreen_toggle(assigns) do
    ~H"""
    <button
      type="button"
      tabindex="-1"
      data-space-fullscreen-toggle
      data-testid="space-fullscreen-toggle"
      aria-label={dgettext("chat", "Toggle fullscreen")}
      class="group absolute top-3 right-3 z-10 flex h-9 w-9 items-center justify-center rounded-sm border border-black/50 bg-neutral-900/50 text-neutral-200 opacity-60 select-none hover:opacity-100 data-[fullscreen]:opacity-80"
    >
      <Icons.icon_fullscreen_enter class="h-4 w-4 group-data-[fullscreen]:hidden" />
      <Icons.icon_fullscreen_exit class="hidden h-4 w-4 group-data-[fullscreen]:block" />
    </button>
    """
  end
end
