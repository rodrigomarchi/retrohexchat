defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.AddressBookPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.AddressBook
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Address Book"),
       active_page: "address-book",
       contacts: [
         %{
           contact_nickname: "alice",
           note: dgettext("showcase", "Friend"),
           first_contact_date: DateTime.add(DateTime.utc_now(), -30, :day)
         },
         %{
           contact_nickname: "bob",
           note: dgettext("showcase", "Colleague"),
           first_contact_date: DateTime.add(DateTime.utc_now(), -7, :day)
         },
         %{contact_nickname: "carol", note: "", first_contact_date: DateTime.utc_now()}
       ]
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Address Book")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Address Book")}
        description="Saved contacts with notes — the panel composes into a desktop window in the chat."
      >
        <div class="h-[420px] shadow-retro-field overflow-hidden p-2">
          <.address_book_panel
            id="address-book-demo"
            contacts={@contacts}
            nick_color_fn={fn nick -> "nick-color-#{:erlang.phash2(nick, 12)}" end}
          />
        </div>
        <.code_example>
          &lt;.address_book_panel
          id="address-book"
          contacts=&#123;@contacts&#125;
          /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end

  # A showcase page renders the component and nothing behind it, so the
  # controls it draws have nowhere to go. Answering them is what keeps a
  # click from taking the page down with an unmatched event.
  @impl true
  def handle_event(_event, _params, socket), do: {:noreply, socket}
end
