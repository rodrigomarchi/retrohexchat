defmodule RetroHexChatWeb.Components.UI.NickPortraitTest do
  @moduledoc """
  The face beside a nickname, and the case that matters more: no face.

  Somebody who never walked into a space has not chosen a character, and the row
  draws nothing at all for them. A placeholder silhouette would put a stranger
  where a person is, which reads worse than the plain text this chat is made of.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.NickPortrait

  @moduletag :unit

  test "draws the chosen character" do
    html = render_component(&nick_portrait/1, avatar: "knight", nickname: "Ada")

    assert html =~ "rh-portrait--knight"
    assert html =~ ~s(data-testid="nick-portrait-knight")
    assert html =~ ~s(title="Ada")
  end

  # Absence, not a placeholder.
  test "draws nothing for somebody who never chose" do
    html = render_component(&nick_portrait/1, avatar: nil, nickname: "Ada")

    refute html =~ "rh-portrait"
  end

  # The art is authored at one size and shown at that size, so the class alone
  # carries the geometry: a component that emitted width or height would be the
  # second place deciding it, and the two would drift.
  test "carries no size of its own" do
    html = render_component(&nick_portrait/1, avatar: "monk")

    refute html =~ "width"
    refute html =~ "height"
    refute html =~ "style"
  end
end
