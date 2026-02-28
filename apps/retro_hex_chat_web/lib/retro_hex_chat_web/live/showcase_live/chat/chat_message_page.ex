defmodule RetroHexChatWeb.ShowcaseLive.Chat.ChatMessagePage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ChatMessage
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Chat Message", active_page: "chat-message")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Chat Message</h2>

      <.showcase_card
        title="Normal Messages"
        description="Standard IRC messages with timestamps and colored nicks."
      >
        <.chat_message_list class="min-h-[120px]">
          <.chat_message timestamp="27/02 11:49" nick="Brutus" nick_color="text-teal">
            *nods silently* Stay out of trouble, Troll.
          </.chat_message>
          <.chat_message timestamp="27/02 11:49" nick="Reginald" nick_color="text-success-dark">
            *tips hat* Do return soon, Troll.
          </.chat_message>
          <.chat_message timestamp="27/02 11:49" nick="Patches" nick_color="text-error">
            Troll heading out? Cool cool. The lobby will keep your seat warm.
          </.chat_message>
          <.chat_message timestamp="27/02 12:08" nick="Reginald" nick_color="text-success-dark">
            *adjusts monocle* Reginald here &mdash; your server concierge.
          </.chat_message>
        </.chat_message_list>
        <.code_example>
          &lt;.chat_message_list&gt;
          &lt;.chat_message timestamp="27/02 11:49" nick="Brutus" nick_color="text-teal"&gt;
          *nods silently* Stay out of trouble, Troll.
          &lt;/.chat_message&gt;
          &lt;/.chat_message_list&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Message Types"
        description="Different message types: action, system, error, notice, service."
      >
        <.chat_message_list class="min-h-[140px]">
          <.chat_message timestamp="14:30" nick="Troll" type="normal" nick_color="text-link">
            Hello everyone!
          </.chat_message>
          <.chat_message timestamp="14:30" nick="Troll" type="action">
            waves to the channel
          </.chat_message>
          <.chat_message timestamp="14:31" type="system">
            Troll has joined the channel.
          </.chat_message>
          <.chat_message timestamp="14:31" type="error">
            Cannot send to channel: you are banned.
          </.chat_message>
          <.chat_message timestamp="14:32" type="notice">
            [Server] Maintenance in 5 minutes.
          </.chat_message>
          <.chat_message timestamp="14:32" type="service">
            ChanServ has set mode +o Troll.
          </.chat_message>
        </.chat_message_list>
        <.code_example>
          &lt;.chat_message timestamp="14:30" nick="Troll" type="action"&gt;
          waves to the channel
          &lt;/.chat_message&gt;
          &lt;.chat_message timestamp="14:31" type="system"&gt;
          Troll has joined the channel.
          &lt;/.chat_message&gt;
          &lt;.chat_message timestamp="14:31" type="error"&gt;
          Cannot send to channel: you are banned.
          &lt;/.chat_message&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="Nick Colors" description="Different nick colors for user identification.">
        <.chat_message_list class="min-h-[100px]">
          <.chat_message timestamp="15:00" nick="Alice" nick_color="text-error">Hey!</.chat_message>
          <.chat_message timestamp="15:00" nick="Bob" nick_color="text-link">Hi Alice!</.chat_message>
          <.chat_message timestamp="15:01" nick="Charlie" nick_color="text-teal">
            What's up?
          </.chat_message>
          <.chat_message timestamp="15:01" nick="Diana" nick_color="text-action">
            Not much, you?
          </.chat_message>
          <.chat_message timestamp="15:02" nick="Reginald" nick_color="text-success-dark">
            Greetings, everyone.
          </.chat_message>
        </.chat_message_list>
      </.showcase_card>

      <.showcase_card
        title="Long Messages & Wrapping"
        description="Messages with long text wrap properly within the grid."
      >
        <.chat_message_list class="min-h-[80px]">
          <.chat_message timestamp="16:00" nick="Patches" nick_color="text-error">
            Troll heading out? Cool cool. The lobby will keep your seat warm. We're always open. Like a 24/7 diner but with better Wi-Fi.
          </.chat_message>
          <.chat_message timestamp="16:01" nick="Brutus" nick_color="text-teal">
            Brutus here &mdash; I keep the peace. Play nice and we'll get along. Type !rules if you need a reminder.
          </.chat_message>
        </.chat_message_list>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
