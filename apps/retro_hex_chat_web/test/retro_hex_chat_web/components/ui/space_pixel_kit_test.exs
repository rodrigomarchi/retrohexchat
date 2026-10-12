defmodule RetroHexChatWeb.Components.UI.SpacePixelKitTest do
  @moduledoc """
  The space's screens wear its pixel-art kit (features/space-ui.css), not the
  platform's Win98 chrome, and keep every hook and test id they had.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.SpaceCharacterSelect
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

  test "the picker is a parchment panel of slots, the chosen one pressed" do
    html =
      render_component(&space_character_select/1,
        avatars: ~w(hero knight),
        selected: "knight",
        roster: [],
        footer: []
      )

    assert html =~ "space-ui-panel"
    assert html =~ "space-ui-slot"
    assert html =~ ~s(data-testid="space-avatar-knight")
    assert [_] = Regex.scan(~r/aria-pressed="true"/, html)
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
