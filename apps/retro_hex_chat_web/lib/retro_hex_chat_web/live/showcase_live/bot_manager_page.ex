defmodule RetroHexChatWeb.ShowcaseLive.BotManagerPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.BotManager
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Bot Manager",
       active_page: "bot-manager",
       bots: [
         %{name: "QuizBot", active: true, channels: ["#lobby", "#trivia"]},
         %{name: "MusicBot", active: true, channels: ["#music"]},
         %{name: "LogBot", active: false, channels: ["#admin"]}
       ]
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Bot Manager</h2>

      <.showcase_card
        title="Bot Manager"
        description="Manage bots with status and channel assignments."
      >
        <.button variant="outline" phx-click={show_modal("bot-manager-demo")}>
          <:icon><Icons.icon_robot class="w-4 h-4" /></:icon>
          Bot Manager
        </.button>
        <.bot_manager id="bot-manager-demo" bots={@bots} />
        <.code_example>
          &lt;.bot_manager id="bot-manager" bots=&#123;@bots&#125; /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
