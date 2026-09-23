defmodule RetroHexChatWeb.ChatLive.UnreadDividerTest do
  @moduledoc """
  The rule that says "everything below this is new".

  Drawn by the row that follows the last line the reader saw, not inserted as a
  row of its own: a synthetic stream item reorders with its neighbours and is
  pruned by the viewport's negative `limit:`, which is what removes the rows a
  prepend just added.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.ChatLive.Components.MessageRow

  @moduletag :unit

  defp render_row(id, boundary_id) do
    render_component(&message_row/1,
      dom_id: "message-#{id}",
      msg: %{id: id, author: "Ana", content: "line #{id}", timestamp: DateTime.utc_now()},
      nick_color_fn: fn _nick -> nil end,
      timestamp_format: :short,
      timezone: "Etc/UTC",
      strip_formatting: false,
      edit_mode_message_id: nil,
      unread_boundary_id: boundary_id
    )
  end

  test "the row at the boundary draws the rule above itself" do
    assert render_row(7, 7) =~ ~s(data-testid="unread-divider")
  end

  # Every other row on the same page must not, or the conversation reads as one
  # long stack of separators.
  test "no other row on the page draws it" do
    refute render_row(6, 7) =~ ~s(data-testid="unread-divider")
    refute render_row(8, 7) =~ ~s(data-testid="unread-divider")
  end

  # A first visit has no "new".
  test "a conversation with no marker draws nothing" do
    refute render_row(7, nil) =~ ~s(data-testid="unread-divider")
  end
end
