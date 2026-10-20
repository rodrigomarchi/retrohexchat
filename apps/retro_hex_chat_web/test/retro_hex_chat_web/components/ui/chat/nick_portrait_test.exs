defmodule RetroHexChatWeb.Components.UI.NickPortraitTest do
  @moduledoc """
  The face beside a nickname, and the case that matters more: no face.

  Somebody who never walked into a space has not made a character, and the row
  draws nothing at all for them. A placeholder silhouette would put a stranger
  where a person is, which reads worse than the plain text this chat is made of.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.NickPortrait

  alias RetroHexChatWeb.CharacterPortrait

  @moduletag :unit

  @recipe "c1.b-av.s-2.o-tun-0-3.h-lng-2.w-0.f-0"

  test "draws the character's face from its recipe" do
    html = render_component(&nick_portrait/1, avatar: @recipe, nickname: "Ada")

    assert html =~ "rh-portrait"
    assert html =~ ~s(src="#{CharacterPortrait.path(@recipe)}")
    assert html =~ ~s(data-avatar="#{@recipe}")
    assert html =~ ~s(title="Ada")
  end

  # Absence, not a placeholder.
  test "draws nothing for somebody who never chose" do
    html = render_component(&nick_portrait/1, avatar: nil, nickname: "Ada")

    refute html =~ "rh-portrait"
  end

  # The art is shown at the size it was drawn, which the image says up front so
  # a row does not jump when it arrives.
  test "is the size the portrait was drawn at" do
    html = render_component(&nick_portrait/1, avatar: @recipe)
    size = CharacterPortrait.size()

    assert html =~ ~s(width="#{size}")
    assert html =~ ~s(height="#{size}")
  end
end
