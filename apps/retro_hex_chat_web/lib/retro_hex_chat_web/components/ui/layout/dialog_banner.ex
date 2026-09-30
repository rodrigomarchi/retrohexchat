defmodule RetroHexChatWeb.Components.UI.DialogBanner do
  @moduledoc """
  The Win98 wizard band at the head of a dialog: an illustration column beside
  a heading and one paragraph saying what this window is for.

  The illustration is not decoration. It pictures the subject in the state it
  is actually in — the way Display Properties drew a monitor showing the
  wallpaper you were about to pick — so the reader knows where they stand
  before reading a word. A dialog whose subject has no state worth drawing
  takes the `glyph` alone and skips the band.
  """
  use RetroHexChatWeb.Component

  @doc """
  Renders the banner: illustration, heading, prose.

  The `art` slot is a `Diagrams.*` illustration and is hidden when the desktop
  stacks, where a 128px column would crowd out the sentence it explains; the
  `glyph` slot (a 32×32 icon) stands in for it there.
  """
  attr :heading, :string, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  slot :art, doc: "Wide illustration drawn by a Diagrams.* component"
  slot :glyph, doc: "32×32 icon shown in place of the illustration on a stacked desktop"
  slot :inner_block, required: true, doc: "One paragraph on what this window is for"

  @spec dialog_banner(map()) :: Phoenix.LiveView.Rendered.t()
  def dialog_banner(assigns) do
    ~H"""
    <div
      class={classes(["dlg-banner shadow-retro-field bg-surface p-retro-6", @class])}
      data-dialog-banner
      {@rest}
    >
      <div :if={@art != []} class="dlg-banner__art shadow-retro-sunken">
        {render_slot(@art)}
      </div>

      <div :if={@glyph != []} class="dlg-banner__glyph">
        {render_slot(@glyph)}
      </div>

      <div class="dlg-banner__body space-y-retro-4">
        <p class="text-sm font-bold">{@heading}</p>
        <div class="text-xs text-muted-foreground">{render_slot(@inner_block)}</div>
      </div>
    </div>
    """
  end
end
