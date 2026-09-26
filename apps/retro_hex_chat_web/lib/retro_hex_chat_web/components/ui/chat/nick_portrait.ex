defmodule RetroHexChatWeb.Components.UI.NickPortrait do
  @moduledoc """
  The face of the character somebody chose, beside their nickname.

  The same art the virtual space draws, windowed onto the head. A crop rather
  than a resize: this product's pixel art is authored at one size and shown at
  that size, and a face scaled down to fit a line of text is a different, worse
  drawing than the one somebody picked.

  Draws nothing at all when there is no character. Somebody who has never walked
  into a space has not chosen, and a placeholder silhouette would put a stranger
  where a person is — worse than the plain text the mIRC look is made of.

  ## Usage

      <.nick_portrait avatar="knight" nickname="Ada" />
  """
  use RetroHexChatWeb.Component

  attr :avatar, :string, default: nil, doc: "the chosen character id, or nil"
  attr :nickname, :string, default: nil, doc: "who it is, for the tooltip"
  attr :class, :any, default: nil
  attr :rest, :global

  @spec nick_portrait(map()) :: Phoenix.LiveView.Rendered.t()
  def nick_portrait(assigns) do
    ~H"""
    <span
      :if={@avatar}
      class={classes(["rh-portrait", "rh-portrait--#{@avatar}", @class])}
      title={@nickname}
      aria-hidden="true"
      data-testid={"nick-portrait-#{@avatar}"}
      {@rest}
    />
    """
  end
end
