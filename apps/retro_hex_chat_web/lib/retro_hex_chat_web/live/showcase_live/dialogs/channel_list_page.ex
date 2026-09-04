defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.ChannelListPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ChannelList
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Channel List"),
       active_page: "channel-list",
       channels: [
         %{
           name: "#lobby",
           user_count: 142,
           topic: dgettext("showcase", "Welcome to RetroHexChat!")
         },
         %{name: "#help", user_count: 38, topic: dgettext("showcase", "Ask your questions here")},
         %{name: "#dev", user_count: 24, topic: dgettext("showcase", "Development discussion")},
         %{
           name: "#music",
           user_count: 67,
           topic: dgettext("showcase", "Share your favorite tunes")
         },
         %{name: "#gaming", user_count: 89, topic: dgettext("showcase", "Game on!")},
         %{name: "#random", user_count: 53, topic: dgettext("showcase", "Anything goes")}
       ]
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
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Channel List")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Channel List")}
        description="Searchable channel table with user count and topic."
      >
        <div class="h-[360px] shadow-retro-field overflow-hidden p-2">
          <.channel_list_panel id="channel-list-demo" channels={@channels} />
        </div>
        <.code_example>
          &lt;.channel_list_panel
          id="channel-list"
          channels=&#123;@channels&#125;
          on_search="filter_channels"
          on_select="select_channel"
          on_join="join_channel"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "With Selection")}
        description="Channel list with a channel pre-selected. Join button is enabled."
      >
        <div class="h-[360px] shadow-retro-field overflow-hidden p-2">
          <.channel_list_panel
            id="channel-list-selected"
            channels={@channels}
            selected_channel="#dev"
          />
        </div>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Loading State")}
        description="Channel list showing the 'Searching...' state while fetching channels."
      >
        <div class="h-[200px] shadow-retro-field overflow-hidden p-2">
          <.channel_list_panel
            id="channel-list-loading"
            channels={[]}
            loading={true}
            search="game"
          />
        </div>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
