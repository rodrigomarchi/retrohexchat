defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.AdminChannelsDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.AdminChannelsDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Admin Channels Dialog"),
       active_page: "admin-channels-dialog",
       show_channels: false
     )}
  end

  @impl true
  def handle_event("toggle_channels", _params, socket) do
    {:noreply, assign(socket, show_channels: !socket.assigns.show_channels)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Admin Channels Dialog")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Admin Channels")}
        description="Channel registry, destructive operations and ChanServ administration."
      >
        <.button variant="outline" phx-click="toggle_channels">
          <:icon><Icons.icon_channels class="w-4 h-4" /></:icon>
          {dgettext("showcase", "Open Admin Channels")}
        </.button>
        <.admin_channels_dialog
          id="admin-channels-demo"
          show={@show_channels}
          text={dgettext("showcase", "*** Channel List (2 results) ***\n  #lobby\n  #dev")}
          banlist_text={dgettext("showcase", "*** No bans in #lobby")}
          search="lo"
          info_channel="#lobby"
          can_refresh={true}
          on_cancel="toggle_channels"
        />
        <.code_example>
          &lt;.admin_channels_dialog
          id="admin-channels"
          show=&#123;@show_channels&#125;
          text=&#123;@channels_text&#125;
          can_refresh=&#123;true&#125;
          on_cancel="close_admin_channels"
          /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
