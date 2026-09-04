defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.BotManagementDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.BotManagementDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PaginatedList.State

  @impl true
  def mount(_params, _session, socket) do
    bots = [
      %{
        name: "DiceBot",
        nickname: "DiceBot",
        command_prefix: "!",
        description: dgettext("showcase", "Rolls dice for the table"),
        enabled: true,
        cooldown_ms: 2000,
        created_by: "admin",
        capabilities: %{
          "dice" => %{"enabled" => true, "max_dice" => 10, "max_sides" => 100},
          "greeter" => %{"enabled" => false}
        },
        channel_configs: [%{channel_name: "#games"}],
        custom_commands: [%{trigger: "roll"}]
      },
      %{
        name: "ModBot",
        nickname: "Guard",
        command_prefix: ".",
        description: dgettext("showcase", "Watches for spam and flooding"),
        enabled: false,
        cooldown_ms: 500,
        created_by: "admin",
        capabilities: %{"moderation" => %{"enabled" => true, "action" => "warn"}},
        channel_configs: [%{channel_name: "#lobby"}, %{channel_name: "#help"}],
        custom_commands: []
      }
    ]

    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Bot Management Dialog"),
       active_page: "bot-management-dialog",
       bots: bots,
       running: ["DiceBot"],
       selected: List.first(bots),
       channels: [%{name: "#games", status: "joined"}],
       commands: [
         %{
           trigger: "roll",
           response: dgettext("showcase", "Rolls a dice (1-20)"),
           description: dgettext("showcase", "Rolls a dice")
         }
       ],
       events_state: State.new(),
       stats: %{messages: 1234, commands: 567, uptime: dgettext("showcase", "3 days, 12 hours")},
       is_admin: true
     )
     |> stream(:events, [
       %{
         id: 1,
         event_type: "channel_user_joined",
         channel: "#games",
         inserted_at: minutes_ago(4)
       },
       %{id: 2, event_type: "message_response", channel: "#games", inserted_at: minutes_ago(2)}
     ])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Bot Management Dialog")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Roster")}
        description="Every bot with its process state, purpose, channels and capabilities."
      >
        <.button variant="outline" phx-click={show_modal("bot-roster-demo")}>
          <:icon><Icons.icon_dialog_bot_management class="w-4 h-4" /></:icon>
          {dgettext("showcase", "Open the roster")}
        </.button>
        <.bot_management_dialog
          id="bot-roster-demo"
          bots={@bots}
          running={@running}
          selected={nil}
          is_admin={@is_admin}
        />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Bot detail")}
        description="The screen a selection drills into; going back clears the selection."
      >
        <.button variant="outline" phx-click={show_modal("bot-detail-demo")}>
          <:icon><Icons.icon_dialog_bot_management class="w-4 h-4" /></:icon>
          {dgettext("showcase", "Open a bot")}
        </.button>
        <.bot_management_dialog
          id="bot-detail-demo"
          bots={@bots}
          running={@running}
          selected={@selected}
          channels={@channels}
          commands={@commands}
          events={@streams.events}
          events_state={@events_state}
          stats={@stats}
          is_admin={@is_admin}
        />
        <.code_example>
          &lt;.bot_management_dialog
          id="bot-mgmt"
          bots=&#123;@bots&#125;
          running=&#123;@running&#125;
          selected=&#123;@selected&#125;
          is_admin=&#123;@is_admin&#125;
          /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end

  defp minutes_ago(minutes), do: DateTime.add(DateTime.utc_now(), -minutes * 60, :second)
  # A showcase page renders the component and nothing behind it, so the
  # controls it draws have nowhere to go. Answering them is what keeps a
  # click from taking the page down with an unmatched event.
  @impl true
  def handle_event(_event, _params, socket), do: {:noreply, socket}
end
