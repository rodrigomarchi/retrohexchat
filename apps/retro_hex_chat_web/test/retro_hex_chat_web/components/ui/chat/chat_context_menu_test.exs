defmodule RetroHexChatWeb.Components.UI.ChatContextMenuTest do
  @moduledoc """
  The menu a right-click or a long press opens on a line. It carries the quick
  reactions on top, because the line itself no longer draws a smiley at rest.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.ChatContextMenu

  alias RetroHexChatWeb.Components.UI.MessageReactions

  @moduletag :unit

  defp message_menu(message) do
    render_component(&chat_context_menu/1,
      visible: true,
      type: :message,
      target_message: message,
      on_action: "chat_context_action"
    )
    |> LazyHTML.from_fragment()
  end

  test "a line's menu offers every quick reaction for that line" do
    doc = message_menu(%{id: 42, text: "hi", nick: "ana"})

    picks = LazyHTML.query(doc, "[data-testid^=context-menu-react-pick-]")

    assert Enum.count(picks) == length(MessageReactions.quick_picks())
    assert LazyHTML.attribute(picks, "phx-value-action") |> Enum.uniq() == ["ctx_chat_react_pick"]
    assert LazyHTML.attribute(picks, "phx-value-message_id") |> Enum.uniq() == ["42"]
    assert LazyHTML.attribute(picks, "phx-value-emoji") == MessageReactions.quick_picks()
  end

  test "a line that cannot be reacted to offers no quick reactions" do
    doc = message_menu(%{id: "pending_3", text: "hi", nick: "ana"})

    assert doc |> LazyHTML.query("[data-testid^=context-menu-react-pick-]") |> Enum.count() == 0
  end

  test "on a phone the line's menu is a bottom sheet" do
    doc = message_menu(%{id: 42, text: "hi", nick: "ana"})

    assert doc |> LazyHTML.query("#chat-context-menu[data-sheet=true]") |> Enum.count() == 1
  end
end
