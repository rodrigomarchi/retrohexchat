defmodule RetroHexChatWeb.ChatLive.Components.AddressBookDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Accounts.{ContactList, NickColors, Session}
  alias RetroHexChatWeb.App.ChatHelpers
  alias RetroHexChatWeb.ChatLive.Components.AddressBookDialog

  @moduletag :unit

  defp session(overrides \\ %{}) do
    base = Session.new("Nick")

    Enum.reduce(overrides, base, fn
      {:contacts, c}, s -> Session.set_contacts(s, c)
      {:nick_colors, n}, s -> Session.set_nick_colors(s, n)
    end)
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

  test "renders the bare panel with the 4 tabs" do
    html = dialog(%{})

    assert html =~ ~s(id="address-book-dialog-mount")
    assert html =~ ~s(data-testid="address-book-panel")
    refute html =~ "phx-show-modal"
    assert html =~ "Contacts"
    assert html =~ "Notify"
    assert html =~ "Nick Colors"
    assert html =~ "Control"
  end

  test "renders contact rows from the session" do
    {:ok, contacts} = ContactList.add_entry(ContactList.new(), "Nick", "Buddy", "a note")
    html = dialog(%{session: session(%{contacts: contacts})})

    assert html =~ "Buddy"
  end

  test "renders nick-color rows from the session" do
    {:ok, colors} = NickColors.add_entry(NickColors.new(), "ColorBud", 4)

    html =
      dialog(%{address_book_tab: "colors", session: session(%{nick_colors: colors})})

    assert html =~ "ColorBud"
    assert html =~ "irc-bg-4"
  end

  test "renders the contact add sub-form targeting the component" do
    html = dialog(%{show_contact_add_dialog: true})

    assert html =~ ~s(data-testid="contact-add-form")
    assert html =~ ~s(phx-target=)
  end
end
