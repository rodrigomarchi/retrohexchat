defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.OpenTabConfirmDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.OpenTabConfirmDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers

  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Open Tab Confirmation"),
       active_page: "open-tab-confirm"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">
        {dgettext("showcase", "Open Tab Confirmation")}
      </h2>

      <.showcase_card
        title={dgettext("showcase", "A room of ours")}
        description="The door into a conference, a space or a game. Named, and no address."
      >
        <.button variant="outline" phx-click={show_modal("open-tab-surface")}>
          <:icon><Icons.icon_link class="w-4 h-4" /></:icon>
          {dgettext("showcase", "Show Surface")}
        </.button>
        <.open_tab_confirm_dialog
          id="open-tab-surface"
          target={%{kind: :surface, url: "/call/demo", label: "Call in #retro"}}
        />
        <.code_example>
          &lt;.open_tab_confirm_dialog
          id="open-tab-surface"
          target=&#123;%&#123;kind: :surface, url: "/call/demo", label: "Call in #retro"&#125;&#125;
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "An attachment")}
        description="A file of ours, named by the tile that offered it."
      >
        <.button variant="outline" phx-click={show_modal("open-tab-attachment")}>
          <:icon><Icons.icon_file_send class="w-4 h-4" /></:icon>
          {dgettext("showcase", "Show Attachment")}
        </.button>
        <.open_tab_confirm_dialog
          id="open-tab-attachment"
          target={%{kind: :attachment, url: "/chat/attachments/7", label: "holiday.png"}}
        />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Somewhere else")}
        description="The host in the sentence and the whole address under it — the one thing a reader can act on."
      >
        <.button variant="outline" phx-click={show_modal("open-tab-external")}>
          <:icon><Icons.icon_globe class="w-4 h-4" /></:icon>
          {dgettext("showcase", "Show External")}
        </.button>
        <.open_tab_confirm_dialog
          id="open-tab-external"
          target={
            %{
              kind: :external,
              url: "https://tecnoblog.net/noticias/uma-manchete-bem-comprida-para-quebrar-linha/",
              host: "tecnoblog.net"
            }
          }
        />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Off-site with no host to name")}
        description="The arcade: our own path, redirecting to the static host. The sentence stands, the address is withheld rather than invented."
      >
        <.button variant="outline" phx-click={show_modal("open-tab-arcade")}>
          <:icon><Icons.icon_game_arcade class="w-4 h-4" /></:icon>
          {dgettext("showcase", "Show Arcade")}
        </.button>
        <.open_tab_confirm_dialog
          id="open-tab-arcade"
          target={%{kind: :external, url: "/play/arcade/pong", host: nil}}
        />
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
