defmodule RetroHexChatWeb.ShowcaseLive.ChannelDialogPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ChannelDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Channel Dialog",
       active_page: "channel-dialog",
       bans: [
         %{mask: "*!*@bad.host.com", set_by: "admin", date: "2024-01-15"},
         %{mask: "spammer!*@*", set_by: "moderator", date: "2024-02-20"}
       ]
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Channel Dialog</h2>

      <.showcase_card
        title="Channel Settings"
        description="Channel dialog with General/Modes/Bans tabs."
      >
        <.button variant="outline" phx-click={show_modal("channel-demo")}>
          <:icon><Icons.icon_tab_channel class="w-4 h-4" /></:icon>
          Channel Settings
        </.button>
        <.channel_dialog
          id="channel-demo"
          channel="#lobby"
          topic="Welcome to the lobby!"
          bans={@bans}
        />
        <.code_example>
          &lt;.channel_dialog
          id="channel-demo"
          channel="#lobby"
          topic="Welcome!"
          bans=&#123;@bans&#125;
          /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
