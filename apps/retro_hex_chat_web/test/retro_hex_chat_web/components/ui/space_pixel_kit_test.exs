defmodule RetroHexChatWeb.Components.UI.SpacePixelKitTest do
  @moduledoc """
  The space's screens wear its pixel-art kit (features/space-ui.css), not the
  platform's Win98 chrome, and keep every hook and test id they had.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.SpaceCharacterCreator

  @moduletag :unit

  test "the creator is a parchment panel of slots and tabs, the worn piece pressed" do
    html =
      render_component(&space_character_creator/1,
        id: "creator",
        recipe: "c1.b-av.s-2.o-tun-0-3.h-lng-2.w-0.f-0",
        tab: "hair",
        title: "Make your character",
        roster: [],
        footer: []
      )

    assert html =~ ~s(data-testid="space-creator-option-hair-lng")
    # The long hair is worn, and its colour (the third) is the one chosen.
    assert [_, _] = Regex.scan(~r/aria-pressed="true"/, html)
  end
end
