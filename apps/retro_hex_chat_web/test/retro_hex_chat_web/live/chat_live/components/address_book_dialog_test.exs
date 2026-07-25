defmodule RetroHexChatWeb.ChatLive.Components.AddressBookDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Accounts.{ContactList, Session}
  alias RetroHexChatWeb.App.ChatHelpers
  alias RetroHexChatWeb.ChatLive.Components.AddressBookDialog

  @moduletag :unit

  defp session(contacts \\ nil) do
    base = Session.new("Nick")
    if contacts, do: Session.set_contacts(base, contacts), else: base
  end

  defp dialog(overrides) do
    sess = Map.get(overrides, :session, session())

    base = %{
      id: AddressBookDialog.id(),
      session: sess,
      nick_color_fn: ChatHelpers.build_nick_color_fn(sess),
      timezone: "Etc/UTC"
    }

    render_component(AddressBookDialog, Map.merge(base, Map.delete(overrides, :session)))
  end

  test "exposes a stable id" do
    assert AddressBookDialog.id() == "address-book-dialog"
  end

  test "renders the bare contacts panel" do
    html = dialog(%{})

    assert html =~ ~s(id="address-book-dialog-mount")
    assert html =~ ~s(data-testid="address-book-panel")
    refute html =~ "phx-show-modal"
    assert html =~ "No contacts saved"
  end

  test "the sibling windows are not part of this panel" do
    html = dialog(%{})

    refute html =~ "No entries. Click Add to track a nickname."
    refute html =~ "No custom colors set. Nicknames use automatic colors."
    refute html =~ "No ignored users. Click Add to ignore a nickname."
  end

  test "renders contact rows from the session" do
    {:ok, contacts} = ContactList.add_entry(ContactList.new(), "Nick", "Buddy", "a note")
    html = dialog(%{session: session(contacts)})

    assert html =~ "Buddy"
  end

  test "renders the contact add sub-form targeting the component" do
    html = dialog(%{show_contact_add_dialog: true})

    assert html =~ ~s(data-testid="contact-add-form")
    assert html =~ ~s(phx-target=)
  end
end
