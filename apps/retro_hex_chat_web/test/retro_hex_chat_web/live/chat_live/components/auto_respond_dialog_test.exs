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

  # A row sends its position as a `phx-value-*` string. `remove_entry/2` compares
  # positions with `==`, so a string matches nothing and the rule silently
  # survives — which is exactly what the browser suite caught.
  test "removing by the position a row sends, a string, takes the rule out" do
    {:ok, rules} =
      AutoRespondRules.add_entry(AutoRespondRules.new(), :on_join, "#elixir", "/me waves")

    [entry] = rules.entries

    assert {:ok, updated} = AutoRespondRules.remove_entry(rules, entry.position)
    assert updated.entries == []

    assert {:error, :not_found} =
             AutoRespondRules.remove_entry(rules, to_string(entry.position))
  end
end
