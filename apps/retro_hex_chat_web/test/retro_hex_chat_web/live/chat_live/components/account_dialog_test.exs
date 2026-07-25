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

    assert html =~ "data-testid=\"account-panel\""
    refute html =~ "phx-show-modal"
  end

  test "an unregistered guest gets the register form and the account state" do
    html =
      render_component(AccountDialog,
        id: AccountDialog.id(),
        nickname: "Alice",
        account_state: :guest,
        registered: false,
        identified: false
      )

    assert html =~ "data-testid=\"account-register-only\""
    assert html =~ "Alice"
    assert html =~ "unregistered"
    # Confirm only appears while registering.
    assert html =~ "data-testid=\"account-confirm\""
    refute html =~ "data-testid=\"account-drop-registration\""
  end

  test "a registered nick gets identify plus the drop form, without confirm" do
    html =
      render_component(AccountDialog,
        id: AccountDialog.id(),
        nickname: "Alice",
        account_state: :guest,
        registered: true,
        identified: false
      )

    assert html =~ "data-testid=\"account-identify-only\""
    assert html =~ "data-testid=\"account-drop-registration\""
    refute html =~ "data-testid=\"account-confirm\""
  end

  test "the sibling account windows are not part of this panel" do
    html = render_component(AccountDialog, id: AccountDialog.id(), nickname: "Alice")

    refute html =~ "Bio (about me)"
    refute html =~ "Away message"
    refute html =~ "Receive wallops"
  end
end
