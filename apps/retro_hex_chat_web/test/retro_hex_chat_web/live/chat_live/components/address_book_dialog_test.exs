defmodule RetroHexChatWeb.ChatLive.Components.AddressBookDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Accounts.{ContactList, NickLocales, Session}
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.App.ChatHelpers
  alias RetroHexChatWeb.ChatLive.Components.AddressBookDialog

  @moduletag :unit

  # A registered nickname whose language is on its row, as it is for somebody
  # who opened the chat in Portuguese and left.
  defp speaker(prefix) do
    nickname = "#{prefix}#{System.unique_integer([:positive])}"
    {:ok, _nick} = NickServ.register(nickname, "password123")
    :ok = NickLocales.remember(nickname, "pt_BR", store: true)
    nickname
  end

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

  test "renders the bare contacts panel" do
    html = dialog(%{})

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

  test "draws each contact's language flag beside the nickname" do
    nickname = speaker("Ctc")
    {:ok, contacts} = ContactList.add_entry(ContactList.new(), "Nick", nickname, nil)
    html = dialog(%{session: session(contacts)})

    assert [_flag] =
             html
             |> Floki.parse_fragment!()
             |> Floki.find(
               ~s(#contact-entry-#{nickname} [data-testid="nick-flag"][data-locale="pt_BR"])
             )
  end

  test "renders the contact add sub-form targeting the component" do
    html = dialog(%{show_contact_add_dialog: true})

    assert html =~ ~s(data-testid="contact-add-form")
    assert html =~ ~s(phx-target=)
  end
end
