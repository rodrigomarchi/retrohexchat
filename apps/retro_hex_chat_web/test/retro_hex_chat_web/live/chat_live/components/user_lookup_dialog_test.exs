defmodule RetroHexChatWeb.ChatLive.Components.UserLookupDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.UserLookupDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert UserLookupDialog.id() == "user-lookup"
  end

  test "renders the lookup form, hidden by default" do
    html = render_component(UserLookupDialog, id: UserLookupDialog.id())

    assert html =~ "data-testid=\"user-lookup-form\""
    assert html =~ "Enter nickname..."
    # Both dialogs render their content hidden (CSS) when closed.
    assert html =~ "hidden"
  end

  test "renders the result card from the passthrough lookup_result" do
    result = %{
      kind: :whois,
      nickname: "Alice",
      title: "Whois: Alice",
      rows: [%{label: "Nickname", value: "Alice"}],
      online: true
    }

    html =
      render_component(UserLookupDialog,
        id: UserLookupDialog.id(),
        visible: false,
        result: result
      )

    assert html =~ "data-testid=\"lookup-result-card\""
    assert html =~ "Whois: Alice"
    assert html =~ "lookup-result-query"
  end
end
