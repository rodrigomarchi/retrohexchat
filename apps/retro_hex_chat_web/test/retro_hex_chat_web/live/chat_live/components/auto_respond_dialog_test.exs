defmodule RetroHexChatWeb.ChatLive.Components.AutoRespondDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Chat.AutoRespondRules
  alias RetroHexChatWeb.ChatLive.Components.AutoRespondDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert AutoRespondDialog.id() == "autorespond-dialog"
  end

  test "renders the bare panel by default" do
    html = render_component(AutoRespondDialog, id: AutoRespondDialog.id())

    assert html =~ ~s(data-testid="auto-respond-panel")
    refute html =~ "phx-show-modal"
  end

  test "renders rules from the passthrough struct" do
    {:ok, rules} =
      AutoRespondRules.add_entry(AutoRespondRules.new(), :on_join, "#elixir", "/me waves")

    html =
      render_component(AutoRespondDialog, id: AutoRespondDialog.id(), rules: rules)

    assert html =~ "#elixir"
    # Toggle (always-present per-row control) carries the position to the parent.
    assert html =~ "autorespond_toggle"
  end
end
