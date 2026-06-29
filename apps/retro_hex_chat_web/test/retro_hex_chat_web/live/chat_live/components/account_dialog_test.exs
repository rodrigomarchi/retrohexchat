defmodule RetroHexChatWeb.ChatLive.Components.AccountDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.AccountDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert AccountDialog.id() == "account-dialog"
  end

  test "renders hidden by default" do
    html = render_component(AccountDialog, id: AccountDialog.id(), nickname: "Alice")

    assert html =~ "data-testid=\"account-dialog\""
    assert html =~ "hidden"
  end

  test "renders all four tab panels and the account state when visible" do
    html =
      render_component(AccountDialog,
        id: AccountDialog.id(),
        visible: true,
        nickname: "Alice",
        account_state: :guest,
        registered: false,
        identified: false
      )

    assert html =~ "Register/Login"
    assert html =~ "Bio (about me)"
    assert html =~ "Away message"
    assert html =~ "Receive wallops"
    # Unregistered guest sees the register form and the close event.
    assert html =~ "data-testid=\"account-register-only\""
    assert html =~ "close_account_dialog"
  end
end
