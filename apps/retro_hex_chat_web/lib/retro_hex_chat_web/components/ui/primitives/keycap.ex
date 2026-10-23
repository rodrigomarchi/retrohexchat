defmodule RetroHexChatWeb.Components.UI.Keycap do
  @moduledoc """
  A key on the keyboard, drawn as the key: `Ctrl+Shift+A`, `Space`, `←`.

  The cheatsheet, a game's controls, the retro games panel and the help all
  name keys, and a key the reader is told to press should look the same in
  each of them — raised, like the one under their fingers. The look lives in
  `components/keycap.css`; a host that needs a bigger key (the cheatsheet on
  a phone) sizes it with its own class.

  ## Usage

      <.keycap>Ctrl+Shift+A</.keycap>
  """
  use RetroHexChatWeb.Component

  @doc "Renders a key."
  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  @spec keycap(map()) :: Phoenix.LiveView.Rendered.t()
  def keycap(assigns) do
    ~H"""
    <kbd class={classes(["keycap", @class])} {@rest}>{render_slot(@inner_block)}</kbd>
    """
  end
end
