defmodule RetroHexChatWeb.ShowcaseLive.ChannelListPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ChannelList
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Channel List",
       active_page: "channel-list",
       channels: [
         %{name: "#lobby", users: 142, topic: "Welcome to RetroHexChat!"},
         %{name: "#help", users: 38, topic: "Ask your questions here"},
         %{name: "#dev", users: 24, topic: "Development discussion"},
         %{name: "#music", users: 67, topic: "Share your favorite tunes"},
         %{name: "#gaming", users: 89, topic: "Game on!"},
         %{name: "#random", users: 53, topic: "Anything goes"}
       ]
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Channel List</h2>

      <.showcase_card
        title="Channel List"
        description="Searchable channel table with user count and topic."
      >
        <.button variant="outline" phx-click={show_modal("channel-list-demo")}>
          <:icon><Icons.icon_channels class="w-4 h-4" /></:icon>
          Channel List
        </.button>
        <.channel_list id="channel-list-demo" channels={@channels} />
        <.code_example>
          &lt;.channel_list
            id="channel-list"
            channels=&#123;@channels&#125;
          /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
