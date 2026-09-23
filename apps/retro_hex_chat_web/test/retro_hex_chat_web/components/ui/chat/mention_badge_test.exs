defmodule RetroHexChatWeb.Components.UI.MentionBadgeTest do
  @moduledoc """
  The count that says "this one is about you".

  It has to disappear completely at zero. A badge that renders empty is a badge
  that still takes a slot in every row of the sidebar, and the sidebar is the
  one place where absence is the normal case.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.MentionBadge

  @moduletag :unit

  test "shows the count when somebody named you" do
    html = render_component(&mention_badge/1, count: 3, testid: "mention-badge")

    assert html =~ ~s(data-testid="mention-badge")
    assert html =~ "@3"
  end

  # Beside the grey unread count, a bare number reads as the same number twice.
  test "marks the count so it cannot be read as the unread one" do
    html = render_component(&mention_badge/1, count: 1, testid: "mention-badge")

    assert html =~ "@1"
  end

  test "draws nothing at zero" do
    html = render_component(&mention_badge/1, count: 0, testid: "mention-badge")

    refute html =~ ~s(data-testid="mention-badge")
  end

  # The number is read at a glance in a narrow sidebar, so it is capped the same
  # way the unread count is rather than widening the row.
  test "caps a large count instead of widening the row" do
    html = render_component(&mention_badge/1, count: 250, testid: "mention-badge")

    assert html =~ "@99+"
  end

  test "says what the number means" do
    html = render_component(&mention_badge/1, count: 1, testid: "mention-badge")

    assert html =~ "mention"
  end
end
