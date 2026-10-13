defmodule RetroHexChatWeb.Components.UI.SpacePixelKitTest do
  @moduledoc """
  The space's screens wear its pixel-art kit (features/space-ui.css), not the
  platform's Win98 chrome, and keep every hook and test id they had.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.SpaceCharacterCreator
  import RetroHexChatWeb.Components.UI.SpaceConstructPanel
  import RetroHexChatWeb.Components.UI.SpaceSayBar

  @moduletag :unit

  test "the say bar is a wooden plank with a parchment field and a wooden button" do
    html =
      render_component(&space_say_bar/1,
        id: "say",
        canvas_id: "canvas",
        value: "",
        placeholder: "Say something",
        error: "Only /me works in a space."
      )

    assert html =~ "space-ui-plank"
    assert html =~ "space-ui-field"
    assert html =~ "space-pixel-button"
    assert html =~ "space-icon--send"
    assert html =~ "space-ui-note--error"
    assert html =~ ~s(data-testid="space-say-send")
    refute html =~ "shadow-retro"
  end

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

    assert html =~ "space-ui-panel"
    assert html =~ "space-ui-slot"
    assert html =~ "space-build-tab"
    assert html =~ ~s(data-testid="space-creator-option-hair-lng")
    # The long hair is worn, and its colour (the third) is the one chosen.
    assert [_, _] = Regex.scan(~r/aria-pressed="true"/, html)
    refute html =~ "shadow-retro"
  end

  test "a piece's panel has the kit's field and buttons" do
    html = render_component(&space_construct_panel/1, %{})

    assert html =~ "space-ui-field"
    assert html =~ "space-pixel-button"
    assert html =~ "space-pixel-button--secondary"
    assert html =~ "space-icon--ok"
    assert html =~ "space-icon--cancel"
    assert html =~ ~s(data-testid="space-panel-save")
    refute html =~ "shadow-retro"
  end
end
