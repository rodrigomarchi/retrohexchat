defmodule RetroHexChatWeb.Components.UI.NickPortrait do
  @moduledoc """
  The face of the character somebody made in the Space, beside their nickname.

  The same pieces the space composes, cut at the head and stacked by the server
  (`RetroHexChatWeb.CharacterPortrait`), shown at the size the art was drawn:
  a face scaled down to fit a line of text is a different, worse drawing.

  Draws nothing at all when there is no character. Somebody who has never walked
  into a space has not made one, and a placeholder silhouette would put a
  stranger where a person is — worse than the plain text the mIRC look is made
  of.

  ## Usage

      <.nick_portrait avatar="c1.b-av.s-2.o-tun-0-3.h-lng-2.w-0.f-0" nickname="Ada" />
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.CharacterPortrait

  attr :avatar, :string, default: nil, doc: "the character's recipe, or nil"
  attr :nickname, :string, default: nil, doc: "who it is, for the tooltip"
  attr :class, :any, default: nil
  attr :rest, :global

  @spec nick_portrait(map()) :: Phoenix.LiveView.Rendered.t()
  def nick_portrait(assigns) do
    assigns = assign(assigns, :size, CharacterPortrait.size())

    ~H"""
    <img
      :if={@avatar}
      src={CharacterPortrait.path(@avatar)}
      width={@size}
      height={@size}
      alt=""
      loading="lazy"
      decoding="async"
      class={classes(["rh-portrait", @class])}
      title={@nickname}
      aria-hidden="true"
      data-testid="nick-portrait"
      data-avatar={@avatar}
      {@rest}
    />
    """
  end
end
