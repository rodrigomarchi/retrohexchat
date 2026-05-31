defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.ChannelListPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

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
       page_title: gettext("Channel List"),
       active_page: "channel-list",
       channels: [
         %{name: "#lobby", user_count: 142, topic: gettext("Welcome to RetroHexChat!")},
         %{name: "#help", user_count: 38, topic: gettext("Ask your questions here")},
         %{name: "#dev", user_count: 24, topic: gettext("Development discussion")},
         %{name: "#music", user_count: 67, topic: gettext("Share your favorite tunes")},
         %{name: "#gaming", user_count: 89, topic: gettext("Game on!")},
         %{name: "#random", user_count: 53, topic: gettext("Anything goes")}
       ]
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Channel List")}</h2>

      <.showcase_card
        title={gettext("Channel List")}
        description="Searchable channel table with user count and topic."
      >
        <.button variant="outline" phx-click={show_modal("channel-list-demo")}>
          <:icon><Icons.icon_channels class="w-4 h-4" /></:icon>
          {gettext("Channel List")}
        </.button>
        <.channel_list id="channel-list-demo" channels={@channels} />
        <.code_example>
          &lt;.channel_list
          id="channel-list"
          channels=&#123;@channels&#125;
          on_search="filter_channels"
          on_select="select_channel"
          on_join="join_channel"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={gettext("With Selection")}
        description="Channel list with a channel pre-selected. Join button is enabled."
      >
        <.button variant="outline" phx-click={show_modal("channel-list-selected")}>
          <:icon><Icons.icon_channels class="w-4 h-4" /></:icon>
          {gettext("Channel List (Selected)")}
        </.button>
        <.channel_list
          id="channel-list-selected"
          channels={@channels}
          selected_channel="#dev"
        />
      </.showcase_card>

      <.showcase_card
        title={gettext("Loading State")}
        description="Channel list showing the 'Searching...' state while fetching channels."
      >
        <.button variant="outline" phx-click={show_modal("channel-list-loading")}>
          <:icon><Icons.icon_channels class="w-4 h-4" /></:icon>
          {gettext("Channel List (Loading)")}
        </.button>
        <.channel_list
          id="channel-list-loading"
          channels={[]}
          loading={true}
          search="game"
        />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
