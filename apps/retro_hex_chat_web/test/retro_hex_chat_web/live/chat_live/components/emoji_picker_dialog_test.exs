defmodule RetroHexChatWeb.ChatLive.Components.EmojiPickerDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.EmojiPickerDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert EmojiPickerDialog.id() == "emoji-picker"
  end

  test "renders nothing when hidden" do
    html = render_component(EmojiPickerDialog, id: EmojiPickerDialog.id())

    refute html =~ "data-testid=\"emoji-picker\""
  end

  test "renders category tabs and the emoji grid when visible" do
    html = render_component(EmojiPickerDialog, id: EmojiPickerDialog.id(), visible: true)

    assert html =~ "data-testid=\"emoji-picker\""
    assert html =~ "data-testid=\"emoji-picker-search\""
    assert html =~ "grid grid-cols-8"
    assert html =~ "phx-value-emoji="
    # Selection and search events bubble to the parent.
    assert html =~ "emoji_select"
    assert html =~ "emoji_search"
  end
end
