defmodule RetroHexChatWeb.ChatLive.Components.AccountDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.AccountDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert AccountDialog.id() == "account-dialog"
  end

  test "renders the panel bare (no modal chrome)" do
    html = render_component(AccountDialog, id: AccountDialog.id(), nickname: "Alice")

    assert html =~ "data-testid=\"account-dialog\""
    refute html =~ "phx-show-modal"
  end

  test "renders all four tab panels and the account state" do
    html =
      render_component(AccountDialog,
        id: AccountDialog.id(),
        nickname: "Alice",
        account_state: :guest,
        registered: false,
        identified: false
      )

    assert html =~ "Register/Login"
    assert html =~ "Bio (about me)"
    assert html =~ "Away message"
    assert html =~ "Receive wallops"
    # Unregistered guest sees the register form.
    assert html =~ "data-testid=\"account-register-only\""
  end
end
