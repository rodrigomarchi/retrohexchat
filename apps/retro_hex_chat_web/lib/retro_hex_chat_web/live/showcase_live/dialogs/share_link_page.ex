defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.ShareLinkPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.Components.UI.ShareLinkDialog
  import RetroHexChatWeb.ShowcaseHelpers

  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.Live.ShareControl

  @demo_url "https://retrohexchat.app/join/eatgb43933"

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Share Link"),
       active_page: "share-link"
     )}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, demo_url: @demo_url)

    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Share Link")}</h2>

      <.showcase_card
        title={dgettext("showcase", "The control, in both of its states")}
        description="One button, one size: a surface never has to make room for the link arriving."
      >
        <div class="flex flex-wrap items-center gap-4">
          <.live_component module={ShareControl} id="share-demo-empty" on_share="noop" />
          <.live_component
            module={ShareControl}
            id="share-demo-minted"
            url={@demo_url}
            on_share="noop"
            on_revoke="noop"
          />
          <.live_component
            module={ShareControl}
            id="share-demo-guest"
            available={false}
            on_share="noop"
          />
        </div>
        <.code_example>
          &lt;.live_component module=&#123;ShareControl&#125; id="share-call" url=&#123;@share_url&#125;
          available=&#123;sharable?(@nickname)&#125; on_share="share_call" on_revoke="revoke_call" /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "The dialog")}
        description="Where the address lives: sized by the dialog, not by the chrome it was wedged into."
      >
        <.button variant="outline" phx-click={show_modal("share-dialog-demo")}>
          <:icon><Icons.icon_btn_link class="w-4 h-4" /></:icon>
          {dgettext("showcase", "Open")}
        </.button>
        <.share_link_dialog
          id="share-dialog-demo"
          url={@demo_url}
          on_revoke="noop"
          on_close={show_modal("share-dialog-demo-closed")}
        />
        <.code_example>
          &lt;.share_link_dialog id="share" url=&#123;@share_url&#125; on_close=&#123;...&#125;
          on_revoke="revoke" /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Without a way to close the link")}
        description="A viewer who may see the address but not revoke it gets no Revoke button."
      >
        <.button variant="outline" phx-click={show_modal("share-dialog-readonly")}>
          <:icon><Icons.icon_btn_link class="w-4 h-4" /></:icon>
          {dgettext("showcase", "Open")}
        </.button>
        <.share_link_dialog
          id="share-dialog-readonly"
          url={@demo_url}
          on_close={show_modal("share-dialog-readonly-closed")}
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
