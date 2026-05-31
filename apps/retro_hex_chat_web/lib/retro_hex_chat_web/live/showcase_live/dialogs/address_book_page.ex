defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.AddressBookPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

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
       page_title: gettext("Address Book"),
       active_page: "address-book",
       contacts: [
         %{
           contact_nickname: "alice",
           note: gettext("Friend"),
           first_contact_date: DateTime.add(DateTime.utc_now(), -30, :day)
         },
         %{
           contact_nickname: "bob",
           note: gettext("Colleague"),
           first_contact_date: DateTime.add(DateTime.utc_now(), -7, :day)
         },
         %{contact_nickname: "carol", note: "", first_contact_date: DateTime.utc_now()}
       ],
       notify_list: [
         %{tracked_nickname: "alice", online: true, note: nil, last_seen_at: nil},
         %{
           tracked_nickname: "dave",
           online: false,
           note: gettext("AFK since Monday"),
           last_seen_at: DateTime.add(DateTime.utc_now(), -120, :minute)
         }
       ],
       nick_colors: [
         %{target_nickname: "alice", color_index: 4},
         %{target_nickname: "bob", color_index: 2}
       ],
       control_list: [
         %{nickname: "spammer", ignore_type: :all, expires_at: nil},
         %{
           nickname: "troll",
           ignore_type: :pms,
           expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
         }
       ]
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Address Book")}</h2>

      <.showcase_card
        title={gettext("Address Book")}
        description="Contact list with color assignments."
      >
        <.button variant="outline" phx-click={show_modal("address-book-demo")}>
          <:icon><Icons.icon_dialog_address_book class="w-4 h-4" /></:icon>
          {gettext("Open Address Book")}
        </.button>
        <.address_book
          id="address-book-demo"
          contacts={@contacts}
          notify_list={@notify_list}
          nick_colors={@nick_colors}
          control_list={@control_list}
          nick_color_fn={fn nick -> "nick-color-#{:erlang.phash2(nick, 12)}" end}
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
