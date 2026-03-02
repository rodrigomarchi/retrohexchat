defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.BotManagementDialogPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.BotManagementDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    bots = [
      %{
        name: "DiceBot",
        nickname: "DiceBot",
        prefix: "!",
        active: true,
        capabilities: %{"dice" => %{"enabled" => true, "sides" => 20}}
      },
      %{
        name: "ModBot",
        nickname: "ModBot",
        prefix: ".",
        active: false,
        capabilities: %{"moderation" => %{"enabled" => true}}
      }
    ]

    {:ok,
     assign(socket,
       page_title: "Bot Management Dialog",
       active_page: "bot-management-dialog",
       bots: bots,
       selected: List.first(bots),
       channels: [%{name: "#general", status: "joined"}, %{name: "#games", status: "joined"}],
       commands: [%{trigger: "!roll", response: "Rolls a dice (1-20)"}],
       events: [
         %{timestamp: "12:30", message: "DiceBot joined #general"},
         %{timestamp: "12:31", message: "DiceBot responded to !roll"}
       ],
       stats: %{messages: 1234, commands: 567, uptime: "3d 12h"},
       is_admin: true
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Bot Management Dialog</h2>

      <.showcase_card
        title="Bot Management"
        description="Split-view dialog with bot list, details, and admin controls."
      >
        <.button variant="outline" phx-click={show_modal("bot-mgmt-demo")}>
          <:icon><Icons.icon_dialog_bot_management class="w-4 h-4" /></:icon>
          Open Bot Management
        </.button>
        <.bot_management_dialog
          id="bot-mgmt-demo"
          bots={@bots}
          selected={@selected}
          channels={@channels}
          commands={@commands}
          events={@events}
          stats={@stats}
          is_admin={@is_admin}
        />
        <.code_example>
          &lt;.bot_management_dialog
          id="bot-mgmt"
          bots=&#123;@bots&#125;
          selected=&#123;@selected&#125;
          channels=&#123;@channels&#125;
          is_admin=&#123;@is_admin&#125;
          /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
