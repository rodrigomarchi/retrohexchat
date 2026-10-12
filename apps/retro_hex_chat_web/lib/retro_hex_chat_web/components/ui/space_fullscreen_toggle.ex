defmodule RetroHexChatWeb.Components.UI.SpaceFullscreenToggle do
  @moduledoc """
  Fullscreen toggle for the virtual space, a pixel-art wooden key anchored to the
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

  import RetroHexChatWeb.Components.UI.Space.PixelIcon
  import RetroHexChatWeb.Components.UI.ToolButton

  @spec space_fullscreen_toggle(map()) :: Phoenix.LiveView.Rendered.t()
  def space_fullscreen_toggle(assigns) do
    ~H"""
    <button
      type="button"
      tabindex="-1"
      data-space-fullscreen-toggle
      data-testid="space-fullscreen-toggle"
      aria-label={dgettext("chat", "Toggle fullscreen")}
      class={
        tool_button_class(
          variant: "pixel",
          size: "md",
          # 44px, the touch target the pad's keys have too.
          class: "group absolute top-3 right-3 z-10 h-11 min-h-11 w-11 min-w-11 select-none"
        )
      }
    >
      <.pixel_icon name={:fullscreen_enter} class="group-data-[fullscreen]:hidden" />
      <.pixel_icon name={:fullscreen_exit} class="hidden group-data-[fullscreen]:inline-block" />
    </button>
    """
  end
end
