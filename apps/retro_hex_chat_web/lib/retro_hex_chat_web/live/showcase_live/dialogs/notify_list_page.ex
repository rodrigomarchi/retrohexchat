defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.NotifyListPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.NotifyList
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Notify List"),
       active_page: "notify-list",
       entries: [
         %{tracked_nickname: "alice", online: true, last_seen_at: "now"},
         %{tracked_nickname: "bob", online: false, last_seen_at: gettext("2h ago")},
         %{tracked_nickname: "carol", online: true, last_seen_at: "now"},
         %{tracked_nickname: "dave", online: false, last_seen_at: "yesterday"},
         %{tracked_nickname: "eve", online: false, last_seen_at: gettext("3d ago")}
       ]
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Notify List")}</h2>

      <.showcase_card
        title={gettext("Notify List")}
        description="Track nicks and get notified when they come online or go offline."
      >
        <.button variant="outline" phx-click={show_modal("notify-list-demo")}>
          <:icon><Icons.icon_btn_bell class="w-4 h-4" /></:icon>
          {gettext("Notify List")}
        </.button>
        <.notify_list id="notify-list-demo" entries={@entries} />
        <.code_example>
          &lt;.notify_list
          id="notify-list"
          entries=&#123;@entries&#125;
          auto_whois=&#123;@auto_whois&#125;
          on_select="nl_select"
          on_add="nl_add"
          on_remove="nl_remove"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={gettext("With Selection")}
        description="Notify list with a nick pre-selected. Edit/Remove buttons are enabled."
      >
        <.button variant="outline" phx-click={show_modal("notify-list-selected")}>
          <:icon><Icons.icon_btn_bell class="w-4 h-4" /></:icon>
          {gettext("Notify List (Selected)")}
        </.button>
        <.notify_list
          id="notify-list-selected"
          entries={@entries}
          selected_entry="bob"
        />
      </.showcase_card>

      <.showcase_card
        title={gettext("Auto-Whois Enabled")}
        description="Notify list with the Auto-Whois checkbox ticked."
      >
        <.button variant="outline" phx-click={show_modal("notify-list-whois")}>
          <:icon><Icons.icon_btn_bell class="w-4 h-4" /></:icon>
          {gettext("Notify List (Auto-Whois)")}
        </.button>
        <.notify_list
          id="notify-list-whois"
          entries={@entries}
          auto_whois={true}
        />
      </.showcase_card>

      <.showcase_card
        title={gettext("Empty State")}
        description="Notify list with no tracked nicks."
      >
        <.button variant="outline" phx-click={show_modal("notify-list-empty")}>
          <:icon><Icons.icon_btn_bell class="w-4 h-4" /></:icon>
          {gettext("Notify List (Empty)")}
        </.button>
        <.notify_list id="notify-list-empty" entries={[]} />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
