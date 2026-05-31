defmodule RetroHexChatWeb.ShowcaseLive.Chat.TopicBarPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.TopicBar
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: dgettext("showcase", "Topic Bar"), active_page: "topic-bar")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Topic Bar")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Channel Topic")}
        description="Channel topic with mode badges."
      >
        <.topic_bar
          variant="channel"
          channel_name="#lobby"
          topic="Welcome to RetroHexChat! Please read the rules."
          modes={["+nt", "+l 50"]}
        />
        <.code_example>
          &lt;.topic_bar
          variant="channel"
          channel_name="#lobby"
          topic="Welcome to RetroHexChat!"
          modes={["+nt", "+l 50"]} /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "PM Topic")}
        description="Private message variant."
      >
        <.topic_bar
          variant="pm"
          channel_name="alice"
          topic="Private conversation with alice"
        />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Status Window")}
        description="Status variant for server messages."
      >
        <.topic_bar
          variant="status"
          channel_name="Status"
          topic="Connected to irc.example.com"
        />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "No Topic")}
        description="When no topic is set."
      >
        <.topic_bar
          variant="channel"
          channel_name="#newchannel"
        />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
