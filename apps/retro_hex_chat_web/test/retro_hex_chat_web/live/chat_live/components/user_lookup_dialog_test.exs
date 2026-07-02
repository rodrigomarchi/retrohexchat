defmodule RetroHexChatWeb.ChatLive.Components.UserLookupDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.UserLookupDialog
  alias RetroHexChatWeb.Components.UI.UserLookupDialog, as: UI

  @moduletag :unit

  test "id/0 is stable" do
    assert UserLookupDialog.id() == "user-lookup-dialog"
  end

  test "renders the lookup form bare, with no result card" do
    html = render_component(UserLookupDialog, id: UserLookupDialog.id())

    assert html =~ "data-testid=\"user-lookup-panel\""
    assert html =~ "data-testid=\"user-lookup-form\""
    assert html =~ "Enter nickname..."
    refute html =~ "phx-show-modal"
    refute html =~ "data-testid=\"lookup-result-card\""
  end

  test "panel renders the result card below the form" do
    result = %{
      kind: :whois,
      nickname: "Alice",
      title: "Whois: Alice",
      rows: [%{label: "Nickname", value: "Alice"}],
      online: true
    }

    html =
      render_component(&UI.user_lookup_panel/1,
        id: "user-lookup-dialog",
        result: result
      )

    assert html =~ "data-testid=\"lookup-result-card\""
    assert html =~ "Whois: Alice"
    assert html =~ "lookup-result-query"
    assert html =~ "lookup-result-whowas"
  end
end
