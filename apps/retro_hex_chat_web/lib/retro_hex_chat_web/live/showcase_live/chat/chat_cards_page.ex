defmodule RetroHexChatWeb.ShowcaseLive.Chat.ChatCardsPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.ChatMessage
  import RetroHexChatWeb.Components.UI.EventCard
  import RetroHexChatWeb.Components.UI.InlineHelpCard
  import RetroHexChatWeb.Components.UI.ShareMessageCard
  import RetroHexChatWeb.Components.UI.VisitorGreetingCard
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Chat Cards"),
       active_page: "chat-cards",
       attending: false
     )}
  end

  @impl true
  def handle_event("event_attend", _params, socket),
    do: {:noreply, assign(socket, attending: true)}

  def handle_event("event_unattend", _params, socket),
    do: {:noreply, assign(socket, attending: false)}

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Chat Cards")}</h2>

      <.showcase_card
        title="Shared rooms"
        description="ShareMessageCard on ChatCard layout={:row}: live with Join and Copy link, ended as a record."
      >
        <.chat_message_list class="min-h-[120px]">
          <.chat_message timestamp="09:36" source="System" type="system" layout="stacked">
            * Troll opened the space
            <.share_message_card
              card={live_space()}
              enter_path="/join/demo-space"
              share_url="https://retrohexchat.app/join/demo-space"
            />
          </.chat_message>
          <.chat_message timestamp="13:55" source="System" type="system" layout="stacked">
            * Troll opened a conference
            <.share_message_card card={ended_call()} ended_at_text="15/10/2026 13:55" />
          </.chat_message>
        </.chat_message_list>
      </.showcase_card>

      <.showcase_card
        title="Events"
        description="EventCard: scheduled with the attend button and a surface link, and called off."
      >
        <.chat_message_list class="min-h-[120px]">
          <.chat_message timestamp="10:00" source="System" type="system" layout="stacked">
            * Brutus scheduled an event
            <.event_card
              card={event(false)}
              when_text="25/10 20:00"
              relative_text="in 7 days"
              attending={@attending}
              on_attend="event_attend"
              on_unattend="event_unattend"
              surface_path="/play/pong"
            />
          </.chat_message>
          <.chat_message timestamp="10:05" source="System" type="system" layout="stacked">
            * Brutus called off an event <.event_card card={event(true)} when_text="25/10 20:00" />
          </.chat_message>
        </.chat_message_list>
      </.showcase_card>

      <.showcase_card
        title="Help and greeting"
        description="InlineHelpCard and VisitorGreetingCard on ChatCard's block layout."
      >
        <.chat_message_list class="min-h-[120px]">
          <.chat_message timestamp="10:10" source="Help" type="system" kind="help" layout="stacked">
            <.inline_help_card
              topic_id="channels"
              topic_title="Channels"
              help_url="/chat/help/channels"
            />
          </.chat_message>
          <.chat_message timestamp="10:11" source="System" type="system" layout="stacked">
            <.visitor_greeting_card server="RetroHexChat" guest="Guest4821" channel="#lobby" />
          </.chat_message>
        </.chat_message_list>
      </.showcase_card>
    </.showcase_layout>
    """
  end

  defp live_space do
    %{
      kind: "space",
      state: :live,
      slug: "demo-space",
      channel_name: "#lobby",
      count: 2,
      participants: ["Troll", "Patches"]
    }
  end

  defp ended_call do
    %{
      kind: "call",
      state: :ended,
      slug: "demo-call",
      channel_name: "#lobby",
      metrics: %{duration_seconds: 40, visitors: 1}
    }
  end

  defp event(cancelled?) do
    %{
      event_id: if(cancelled?, do: 2, else: 1),
      title: "Pong tournament",
      description: "Best of three, bring a friend.",
      cancelled?: cancelled?,
      attendee_count: 3
    }
  end
end
