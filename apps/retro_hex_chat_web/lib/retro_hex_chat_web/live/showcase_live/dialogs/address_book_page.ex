defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.AddressBookPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.AddressBook
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Address Book",
       active_page: "address-book",
       contacts: [
         %{nick: "alice", notes: "Friend", color: 4},
         %{nick: "bob", notes: "Colleague", color: 2},
         %{nick: "carol", notes: "", color: 3}
       ],
       notify_list: [
         %{nick: "alice", notify_on: true, notify_off: true},
         %{nick: "dave", notify_on: true, notify_off: false}
       ],
       nick_colors: [
         %{nick: "alice", color: 4},
         %{nick: "bob", color: 2}
       ],
       control_list: [
         %{nick: "spammer", level: "ignore"},
         %{nick: "troll", level: "ban"}
       ]
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Address Book</h2>

      <.showcase_card
        title="Address Book"
        description="Contact list with color assignments."
      >
        <.button variant="outline" phx-click={show_modal("address-book-demo")}>
          <:icon><Icons.icon_dialog_address_book class="w-4 h-4" /></:icon>
          Open Address Book
        </.button>
        <.address_book
          id="address-book-demo"
          contacts={@contacts}
          notify_list={@notify_list}
          nick_colors={@nick_colors}
          control_list={@control_list}
          selected_color={4}
        />
        <.code_example>
          &lt;.address_book
          id="address-book"
          contacts=&#123;@contacts&#125;
          /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
