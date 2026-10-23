defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.AdminChannelsDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.AdminChannelsDialog
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Admin Channels Dialog"),
       active_page: "admin-channels-dialog"
     )}
  end

  # A showcase page renders the component and nothing behind it, so the
  # controls it draws have nowhere to go. Answering them is what keeps a
  # click from taking the page down with an unmatched event.
  @impl true
  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Admin Channels Dialog")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Admin Channels")}
        description="Channel registry, destructive operations and ChanServ administration."
      >
        <div class="relative h-[380px] shadow-retro-field overflow-hidden p-2">
          <.admin_channels_panel
            id="admin-channels-demo"
            text={dgettext("showcase", "*** Channel List (2 results) ***\n  #lobby\n  #dev")}
            banlist_text={dgettext("showcase", "*** No bans in #lobby")}
            search="lo"
            info_channel="#lobby"
            can_refresh={true}
          />
        </div>
        <.code_example>
          &lt;.admin_channels_panel
          id="admin-channels"
          text=&#123;@channels_text&#125;
          can_refresh=&#123;true&#125;
          /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
